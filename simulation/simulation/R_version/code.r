pacman::p_load(tidygraph,tidyverse, ggsci, igraph, R6, glue)

NS <- R6Class(
  "Network Simulation",
  private = list(
    end_ratio = 0.99 # 99%的节点被激活，程序就会结束
  ),
  
  public = list(
    # 模式
    mod = NA,
    # 存储初始化参数的地方
    parameters = list(num_nodes = NA, # 节点数
                      p_rewire = NA, # 改写链接的比例
                      z = NA, # 节点度是多少
                      a = NA), # 阈值是多少
    # 存储状态的地方
    State = list(NA),
    # 最大改写上限
    upper_limit_rewire = NA,
    # 存储图对象的地方
    G = NA,
    # 存储激活节点占比轨迹的地方
    prop_path = vector("numeric", 0),
    # 存储超过99%步数的地方
    times = vector("numeric", 0),
    
    
    # 初始化函数
    initialize = function(num_nodes, p_rewire, z, a, mod, store, echo)  {
      
      # 1.写入参数
      self$parameters$num_nodes <- num_nodes
      self$parameters$p_rewire <- p_rewire
      self$parameters$z <- z
      self$parameters$a <- a
      self$upper_limit_rewire <- (1 - ( (4*a*(a+1)) / (z * (z + 2) ) ))
      self$store <- store
      self$echo <- echo
      self$mod <- mod
      
      
      # 2.生成状态
      g <- play_smallworld(n_dim = 1,
                           dim_size = num_nodes,  # 节点数量
                           order = z / 2,
                           p_rewire = 0) %>%
        # rewire 的同时不改变节点度
        rewire( keeping_degseq(niter = as.integer(ecount(.) * 0.5 * p_rewire)) ) %>%
        as_tbl_graph()
      focal_node <- sample(1:num_nodes, 1) ## 一开始激活一些节点： 随机选择一个节点
      initial_activate <- neighborhood(g, nodes = focal_node)[[1]] # 提取该节点邻节点
      self$State <- rep(0, num_nodes) ; self$State[initial_activate] <- 1 # State是状态向量
      
      # 3. 生成权重矩阵
      Centrality_record <- g %>%
        activate(edges) %>%
        mutate(Centrality = centrality_edge_betweenness(),
               # 按照介数中心度，由低到高划分4个区间
               Cq = as.numeric(cut_number(Centrality, 4)),
               # 模式1的权重
               mode1 = 1,
               # 模式2的权重
               mode2 = ifelse(Cq == 1, 100, 1)) %>% # 只要设一个足够大的数就就行，这里是100
        as_tibble() 
      # 模式3的权重 
      Centrality_record <- Centrality_record %>% # 每个edge生成一个id
        arrange(Cq) %>%
        mutate(id = 1:nrow(.)) %>%
        select(id, everything())
      
      n_record <- Centrality_record %>%  # 统计各分位段的edge有多少
        count(Cq) %>%
        mutate(idduan = cumsum(n))
      
      id_for_strong_in_last <- sample(1:n_record[[1,2]], 0.2 * ecount(g))
      id_for_strong_in_first <- sample((n_record[[3,3]] + 1):n_record[[4,3]], .05 * ecount(g))
      id_for_strong <- c(id_for_strong_in_first, id_for_strong_in_last)
      
      Centrality_record <- 
        Centrality_record %>%
        mutate(mode3 = ifelse(id %in% id_for_strong, 100, 1))
      
      
      # 权重矩阵
      if (mod == 1){
        # 模式1的权重矩阵
        self$Weight <- as_adjacency_matrix(g) %>% as.matrix()
      } else if (mod == 2) {
        # 模式2的权重矩阵
        WM2 <- matrix(NA, nrow = num_nodes, ncol = num_nodes)
        
        for (id in 1:nrow(Centrality_record)){
          i <- Centrality_record$from[id]
          j <- Centrality_record$to[id]
          weight <- Centrality_record$mode2[id]
          
          WM2[i, j] <-  weight
          WM2[j, i] <-  weight
        } 
        self$Weight <- ifelse(is.na(WM2), 0, WM2) # 将NA替换为0
      } else {
        # 模式3 的权重矩阵
        WM3 <- matrix(NA, nrow = num_nodes, ncol = num_nodes)
        
        for (id in 1:nrow(Centrality_record)){
          i <- Centrality_record$from[id]
          j <- Centrality_record$to[id]
          weight <- Centrality_record$mode3[id]
          
          WM3[i, j] <-  weight
          WM3[j, i] <-  weight
        } 
        self$Weight <- ifelse(is.na(WM3), 0, WM3) # 将NA替换为0
      }
    },
    
    
    # 模拟函数
    start_diffusion = function(){
      self$times <- 0 # 计步器
      self$prop_path[1] <- mean(self$State)  # 初始比例
      self$judge_vec <- c(NA, NA) # 帮助判断是否该停止的向量
      # 只要激活节点数量不大于等于99%，程序就进行下去
      while (  mean(self$State) < private$end_ratio) {
        # 遍历所有未激活节点（随机）
        inactive_index <- (self$State == 0) %>% 
          which() %>% 
          sample(size = length(.)) # 打乱顺序
        for (i in inactive_index){
          # 计算节点i所有【已激活】邻节点的权重和
          weight_sum <- sum(self$State * self$Weight[i, ])
          # 将权重和与阈值进行比较，如果超过阈值，设置其状态为1
          if (weight_sum >= self$parameters$a){
            self$State[i] <- 1
          }
        }
        
        
        self$times <- self$times + 1 # 当前迭代次数
        Prop = mean(self$State) # 迭代后激活节点的比例
        if (self$echo){
          print(glue("第{self$times}次迭代后，有{Prop}比例的节点被激活", ))
        }
        if (self$store) {
          self$prop_path <- c(self$prop_path,  Prop)
        }
        # 避免无限循环
        # 如果当前的prop（self$times + 1，因为prop_path里有第一次）等于上一次的prop，就结束循环
        if (self$prop_path[self$times + 1] == self$prop_path[self$times]){
          self$times = 99999
          break
        }
        
      }
      print(glue("**模式{self$mod}:N={self$parameters$num_nodes},z={self$parameters$z}, a={self$parameters$a}, p_rewire={self$parameters$p_rewire}, 时长={self$times}"))
    }
    
    
  ),
  
  lock_objects = F  # 别TM把空间给锁了！
)


# 循环
# 定义参数空间
p_rewire_vector <- 10^seq(-3, 0, by = .1)  # p_rewire
a_vector <- 1:3
mod_vector <- 1:3

Repeat_time <- 100 # 每个参数组合重复多少次
date_names <- "2022-05-13"

# 计数器
#总循环次数
total_iter <- length(p_rewire_vector) * length(a_vector) * length(mod_vector) * Repeat_time 
# 计数器
count_iter <- 1

for (mod in mod_vector) {
  for (a in a_vector){
    for (p_rewire in p_rewire_vector){
      for (j in 1:Repeat_time){
        print(glue("{count_iter} / {total_iter}:"))
        network_simulation <- NS$new(num_nodes = 2000, p_rewire = p_rewire, z = 12, a = a, 
                                     mod = mod, # mode负责调整模式，从而改变Weight矩阵
                                     store = T,# store 是否存储数据
                                     echo = F ) # echo 是否打印 
        network_simulation$start_diffusion() # 运行过程
        d <- tibble(mod = mod,
                    a = a,
                    p = p_rewire,
                    Time = network_simulation$times) %>%
          write_csv(glue("{date_names}.csv"), append = T)
        count_iter <- count_iter + 1
      }
    }
  }
}
