# 绘制一阶导数的对比图

def delta_chart(arr)
    puts render(:double_chart,{:left=>line_chart(arr),:right=>line_chart(diff(arr))})
end

