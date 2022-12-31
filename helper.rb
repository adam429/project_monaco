load './wtcube/wtcube.rb'

# 生成交叉表格
def cross(arr1,arr2)
    ret = []
    arr1.each do |x|
        row = []
        row.push(x[0])
        arr2.each do |y|
            row.push((x[1]*y[1]).round)
        end
        ret.push(row.clone)
    end
    return ret
end


# 绘制一阶导数的对比图
def delta_chart(arr,option={:name=>"",:output=>nil,:type=>method(:diff_rate)})
    row_data = [
        ["值",line_chart(arr,:points=>false)],
        ["一阶变化值",line_chart(option[:type].call(arr),:points=>false)]
     ] 
    html = render(:row_chart,{:data=>[
       :row_name=>option[:name],
       :row_data=> row_data
    ]})

    if option[:output]=="html" then
        return row_data
    else
        puts html
    end
end


def layout_chart(charts,num_per_row,option={:output=>nil})
    return "" if charts.size==0

    cur_chart = []
    num_per_row.times do |x| 
        element = charts.shift
        break if element==nil
        cur_chart.push(element)
    end

    while cur_chart.size < num_per_row do
        cur_chart.push(["-",""])
    end

    html = render(:row_chart,{:data=>[
       :row_name=>"",
       :row_data=>cur_chart
    ]})
    puts html if option[:output]!="html" 

    html=html+layout_chart(charts,num_per_row,:output=>option[:output])
end


# 双图 / 三图 / 四图
def layout_double_chart(chart1,chart2,chart1_name="",chart2_name="",row_name="",option={:output=>nil})
    html = render(:row_chart,{:data=>[
       :row_name=>row_name,
       :row_data=>[[chart1_name,chart1],[chart2_name,chart2]] 
    ]})

    if option[:output]=="html" then
        return html
    else
        puts html
    end
end

def layout_triple_chart(chart1,chart2,chart3,chart1_name="",chart2_name="",chart3_name="",row_name="",option={:output=>nil})
    html = render(:row_chart,{:data=>[
       :row_name=>row_name,
       :row_data=>[[chart1_name,chart1],[chart2_name,chart2],[chart3_name,chart3]] 
    ]})

    if option[:output]=="html" then
        return html
    else
        puts html
    end
end

def layout_quadruple_chart(chart1,chart2,chart3,chart4,chart1_name="",chart2_name="",chart3_name="",chart4_name="",row_name="",option={:output=>nil})
    html = render(:row_chart,{:data=>[
       :row_name=>row_name,
       :row_data=>[[chart1_name,chart1],[chart2_name,chart2],[chart3_name,chart3],[chart4_name,chart4]] 
    ]})

    if option[:output]=="html" then
        return html
    else
        puts html
    end
end


# 通过数值来生成分布的直方图
def gen_dist(arr)
    ret= {}
    ret=arr.group_by do |x| x end.map do |k,v| [k,v.size] end
    ret.sort do |x,y| x[0]<=>y[0] end.to_a
end
    # return ret if ret.size<10
    

    # min = ret[0][0] 
    # max = ret[ret.size-1][0]
    # bar = 8

    # interval = (max-min)/bar
    # count=0

    # bar_ret = []

    # bar.times do |i| 
    #   subtotal=0

    #   while ret[count][0]<min+(i+1)*interval do
    #       subtotal=subtotal+ ret[count][1]
    #       count=count+1
    #   end
          
    #   bar_ret.push ([min+i*interval,subtotal])  
    # end
    
    # return bar_ret
## end

# 插值
def interpolation(arr,x)
    percent = x-x.floor

    return arr[x.floor][1] * (1-percent) + arr[x.ceil][1] * percent
end

#归一化
def normalize(arr,index)
    total = (arr.map do |x| x[index] end).sum
    return arr.map do |x| x[1]=x[index]/total; x end
end


# 参数化生成参数表
def param_table(sim_time, init_value, init_change_rate, diminishing_rate=1, long_term_value=0)
    ret = []

    sim_time = sim_time+1

    cur_value = init_value
    cur_change_rate = init_change_rate

    sim_time.times do |day|
      ret.push ([day,cur_value])

      next_value = cur_value * (1 + cur_change_rate)
      cur_change_rate = cur_change_rate * diminishing_rate 

      if next_value > long_term_value then
        cur_value= next_value
      else
        cur_value = long_term_value
      end
    end

    return ret
end
