# The Quasi-weak Strong Tie and A New Theory on Strong-tie Bridges

## 1. 文件结构：

- **data_analysis**
    - cgss2003_14.dta : CGSS数据
    - code.Rmd : 对CGSS数据的分析
- **simulation**
    - **data_analysis**
      - R_data：在R中跑模拟的结果（p_rewire忘了乘0.5了，搞错了，数据不建议使用）
        - sample_10.csv: 10次循环[^1]
        - sample_20.csv: 20次循环
        - sample_70.csv: 70次循环
        - code.Rmd: 对模拟结果的分析
      - Py_data: 在python中跑模拟的结果
        - code.Rmd:分析
        - sim_record.csv : 数据
    - **simulation**
        - **R_version**
          - code.r : 模拟程序(R版本)
        - **Py_version**
          - code.ipynb: 模拟程序(python版本)
          - code_class.ipynb (面向对象)


[^1]:这几个文件是在服务器和个人电脑分别运行的模拟结果，最后合并出100的样本，否则花费时间太长了。

## 2. 模拟思路

1. 初始化网络
   - 节点数`num_nodes`
   - 改写链接比例`p_rewire`
   - 节点度：和周边多少个体相联系`z`
   - 阈值`a`
2. 生成状态
   - `State`: 1 激活；0 未激活
   - 需要提取随机提起一个节点和邻接点，赋值1。
3. 设置边权重
   - 如果是模式1，则所有权重为1.
   - 如果是模式2或3：
     - 计算中间中心度
     - 从低到高分为四类
     - 按照规则设置权重
4. 模拟程序运行
   1. 计步器t = 0
   2. 激活比例不大于等于99%，就继续下去
   3. 遍历所有未激活点（随机）
   4. 计算周边节点的状态和阈值，求和，对比阈值
   5. 如果超过，设置状态为1
   6. 记录激活比例，并用该比例判断程序是否无限循环，如果是，就结束程序，并加一个无限循环标识
5. 多次模拟
   1. 改写比例空间 `10^seq(-3, 0, by = .1)`
   2. 阈值空间1:3
   3. 模式空间1：3