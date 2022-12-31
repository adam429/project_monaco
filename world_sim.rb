require 'hash_dot'
require 'weighted_sample'
require 'singleton'

Hash.use_dot_syntax = true

class World
    include Singleton

    attr_accessor :config, :table, :vars, :stats, :fishes, :users, :time_count, :hook, :games

    def sim_time()
        return config[:sim_time]
    end

    def reset()
        @stats = {}
    
        #实体
        @fishes = []
        @users = []
        @games = []
    
        @time_count = 0

        @config.new_user=0

        @hook = {
            :before_begin_day => nil,
            :after_begin_day => nil,
            :before_end_day => nil,
            :after_end_day => nil,
            :before_next_day => nil,
            :after_next_day => nil,

        }
    end

    def initialize()
        # 模拟时长 1800天 = 60个月 = 5年
        @config = {
            :sim_time => 60 * 30,
            :new_user => 0
        }

        @vars = {}
    
        #参数表
        @table = {}

        @hook = {
            :before_begin_day => nil,
            :after_begin_day => nil,
            :before_end_day => nil,
            :after_end_day => nil,
            :before_next_day => nil,
            :after_next_day => nil,

        }

        @stats_vars = {
            "user_number" => -> { @users.size },
            "fish_number" => -> { @fishes.size },
            "fish_work" => -> { @fishes.filter do |f| f.work end.size },
            "fish_idel" => -> { @fishes.filter do |f| f.idel end.size},
            "fish_queue" => -> { @fishes.filter do |f| f.queue end.size },
            "fish_nonwork" => -> { @fishes.filter do |f| f.queue end.size + @fishes.filter do |f| f.idel end.size },
            "total_social_output" => -> { @users.map do |x| x.social_output end.sum },
            "totol_proficiency"   => -> { @fishes.map do |x| x.proficiency end.sum },
            "avg_user_level"         => -> { @users.map do |x| x.level end.sum / @users.size.to_f },
            "avg_user_active"        => -> { @users.map do |x| x.active_rate end.sum / @users.size.to_f },
            "avg_user_age"           => -> { @users.map do |x| x.age end.sum / @users.size.to_f },
            "avg_user_social_output" => -> { @users.map do |x| x.social_output end.sum / @users.size.to_f },
            "avg_fish_age"           => -> { @fishes.map do |x| x.age end.sum / @fishes.size.to_f },
            "avg_fish_proficiency"   => -> { @fishes.map do |x| x.proficiency end.sum / @fishes.size.to_f },
            "open_game"              => -> { @games.filter do |g| g.is_open end.size },
            "fish_per_user" => -> { @users.size!=0 ? @fishes.size.to_f / @users.size.to_f : 0 },
            
        }

        @stats = {}
    
        #实体
        @fishes = []
        @users = []
        @games = []
    
        #状态表
        @time_count = 0
    end    

    def record_stats()
        @stats_vars.each do |k,v|
            @stats[k]=[] if @stats[k]==nil 
            @stats[k].push (v.call)
        end
    end

    # 每天流程

    ## begin_day
    ##   新增用户       [ok]
    ##   新增鱼         [ok]
    ##   新增游戏       [ok]
    ##   用户调整鱼的分布 【用户把鱼stake到游戏排队】 [ok]
    ##   抽鱼到挖矿池     [ok]

    ## end_day
    ##   结算挖矿收益
    ##   结算鱼熟练度
    ##   如果游戏结束，释放鱼
    ##   结算用户活跃度 -> 用户行为  [ok]
    ##   用户级别变化              【ok]
    ##   用户活跃度衰减             [ok]
    ##   增加年龄 (鱼和用户)        [ok]

    ## next_day
    ##   增加时间计数器          [ok]

    def run(day=@config.sim_time)
        run_day(day)
    end

    def run_day(day=1)
        day.times do |x|
            @hook.before_begin_day.call if @hook.before_begin_day
            begin_day()
            @hook.after_begin_day.call if @hook.after_begin_day

            @hook.before_end_day.call if @hook.before_end_day
            end_day()
            @hook.after_end_day.call if @hook.after_end_day

            record_stats()

            @hook.before_next_day.call if @hook.before_next_day
            next_day()
            @hook.after_next_day.call if @hook.after_next_day

        end
    end

    def put_fish_to_queue()
        @users.each do |u|
            u.put_fish_to_queue()
        end
    end

    def fish_queue_to_mining()
        @games.each do |g|
            g.move_fish_to_mining_pool if g.is_open
        end
    end

    def begin_day()
        add_user
        put_fish_to_queue 
        fish_queue_to_mining
    end

    def end_day()
        (@fishes+@users+@games).each do |x|
            x.end_day
        end
    end

    def next_day()
        @time_count = @time_count + 1
    end



    def add_user()
        new_user = 0

        if @config.new_user.class == Method then
            new_user = @config.new_user.call
        end

        if @config.new_user.class == Integer then
            new_user = @config.new_user
        end

        new_user.times do |x|
            User.new
        end
    end

end


class Fish
    attr_accessor :level,:power,:agility,:age,:birthday, :user, :game_queue, :game_mining, :proficiency
    def initialize()
        fish = World.instance.table.fish_create_tab.weighted_sample_by do |x|
            (x[1]*100000).round
        end
        @birthday = World.instance.time_count
        @age = 0
        @level = fish[0]
        @agility = fish[2]
        @power = fish[3]
        @user = nil
        @game_queue = nil
        @game_mining = nil
        @proficiency = 0

        World.instance.fishes.push(self)
    end

    def end_day()
        @age = @age + 1
    end

    def exit_game_queue()
        return if @game_queue==nil
        @game_queue.exit_game_queue(self)
        @game_queue=nil
    end

    def exit_game_pool()
        return if @game_mining==nil
        @game_mining.exit_game_pool(self)
        @game_mining=nil
    end

    def add_proficiency()
        @proficiency=@proficiency+1
    end

    def idel()
        @game_mining==nil and @game_queue==nil
    end

    def work()
        @game_mining!=nil
    end

    def queue()
        @game_queue!=nil
    end

    def production
        world = World.instance

        # todo
        # 鱼基础力量值 * 熟练度buff * 年龄buff * 用户级别buff

        # world.table.fish_age_buff[]
        # world[:table][:fish_age_buff][fish[:age]][1] * 
        # interpolation(world[:table][:fish_proficiency_buff],fish[:proficiency]) *
        # fish[:power]
    end
     

end

class User
    attr_accessor :level,:active_rate,:social_output,:age,:birthday, :fishes
    def initialize()
        user = World.instance.table.user_create_tab.weighted_sample_by do |x|
            (x[1]*100000).round
        end
        @birthday = World.instance.time_count
        @age = 0
        @level = 0
        @social_output = 0
        @active_rate = user[1]
        @fishes = []

        World.instance.users.push(self)
    end

    def add_fish(fish)
        @fishes.push(fish)
        fish.user = self
    end

    def put_fish_to_queue()
        world = World.instance
        
        # 没有在游戏的鱼，放到游戏排队最少的queue里面去
        fishes = @fishes.filter do |x| x.idel or x.queue end.each do |f|
            game = Game.short_queue_game();

            # 鱼换等待池排队
            if game!=nil and game!=f.game_queue then
                f.exit_game_queue()
                game.put_fish_to_queue(f)
            end
        end            

        # 在游戏 的鱼，如果有其他游戏，有一定概率换游戏
        fishes = @fishes.filter do |x| x.work end.each do |f|
            
            if rand<world.config.user_fish_switch_rate then
                game = Game.short_queue_game(f.game_queue);

                # 鱼换等待池排队
                if game!=nil and game!=f.game_mining then
                    f.exit_game_pool()
                    game.put_fish_to_queue(f)
                end
            end 
        end

    end

    def end_day()
        @social_output = @social_output + ((rand() < @active_rate) ? 1 : 0)
        @active_rate = (@active_rate * (World.instance.table.user_active_tab[@age+1][1] / World.instance.table.user_active_tab[@age][1])).floor(10)
        if @social_output >= World.instance.table.user_level_tab[@level+2][1] then
            @level=@level+1
            @active_rate=@active_rate*World.instance.table.user_level_tab[@level+1][2]
        end

        @age = @age + 1
    end
end

class Game
    attr_accessor :name,:token,:launch_time,:duration,:total_token, :mining_token,:airdrop_tokon,:mining_limit,:airdrop_limit,:mining_pool,:mining_queue

    def initialize(game)
        @game = game[:game] or ""
        @token = game[:token] or ""
        @launch_time = game[:launch_time] or 0
        @duration = game[:duration] or 0
        @total_token = game[:total_token] or 0
        @mining_token = game[:mining_token] or 0
        @airdrop_tokon = game[:airdrop_tokon] or 0
        @mining_limit = game[:mining_limit] or 0
        @airdrop_limit = game[:mining_limit] or 0
        @mining_pool = []
        @mining_queue = []
    end

    def self.short_queue_game(exclusive=nil)
        game = World.instance.games.filter do |x|
            x.is_open and x!=exclusive
        end.sort do |x,y|
            x.mining_queue.size <=> y.mining_queue.size
        end.first
    end

    def is_open
        world = World.instance
        return ((@launch_time<=world.time_count) and (world.time_count < @launch_time+@duration))
    end

    def put_fish_to_queue(fish)
        @mining_queue.push(fish)
        fish.game_queue = self
        fish.game_mining = nil
    end

    def exit_game_queue(fish)
        @mining_queue.reject! do |x| 
            x==fish
        end
        fish.game_queue = nil
    end

    def put_fish_to_pool(fish)
        @mining_pool.push(fish)
        fish.game_queue = nil
        fish.game_mining = self
    end

    def exit_game_pool(fish)
        @mining_pool.reject! do |x| 
            x==fish
        end
        fish.game_mining = nil
    end


    def move_a_fish_to_mining_pool()

        return if @mining_pool.size == @mining_limit
        return if @mining_queue.size == 0
    
        sel_fish = @mining_queue.weighted_sample_by do |x|
            (x.agility*100).round
        end

        exit_game_queue(sel_fish)
        put_fish_to_pool(sel_fish)
    end
    
    def move_fish_to_mining_pool()
        while true do
            save_mining_queue = @mining_queue.size
            save_mining_pool = @mining_pool.size
        
            move_a_fish_to_mining_pool()
        
            break if (@mining_queue.size==save_mining_queue and @mining_pool.size == save_mining_pool)
        end
    end

    def end_day
        # 结算收益
        # todo

        # 更新鱼熟练度
        @mining_pool.each do |x|
            x.add_proficiency()
        end

        # 结束挖矿的游戏，释放鱼
        if @launch_time + @duration == World.instance.time_count-1 then
            @mining_pool.each do |x|
                x.game_mining=nil
            end
            @mining_pool = []

            @mining_queue.each do |x|
                x.game_queue=nil
            end
            @mining_queue = []
        end
    end
end

# ------------------------------------------------------------v





# -- general world logic --
def world_stats(world)
    puts_header "World Stats (Day=#{world[:states][:time_count]})",:level=>1
    puts "总用户数=#{world[:states][:user_count]}"
    puts "总鱼数量=#{world[:states][:fish_count]}"
    puts "总游戏数=#{world[:states][:game_count]}"

    puts_header "==鱼==",:level=>3

    chart1_name="鱼等级分布"
    chart1 = column_chart(gen_dist(world[:entity][:fishes].map do |x| x[:level] end).to_h)

    chart2_name="鱼敏捷度分布"
    chart2 = column_chart(gen_dist(world[:entity][:fishes].map do |x| x[:agility] end).to_h)

    chart3_name="鱼力量值分布"
    chart3 = column_chart(gen_dist(world[:entity][:fishes].map do |x| x[:power] end).to_h)

    layout_triple_chart(chart1,chart2,chart3,chart1_name,chart2_name,chart3_name)

    chart1_name="鱼年龄分布"
    chart1 = column_chart(gen_dist(world[:entity][:fishes].map do |x| x[:age] end).to_h)

    chart2_name="鱼熟练度"
    chart2 = column_chart(gen_dist(world[:entity][:fishes].map do |x| x[:proficiency] end).to_h)

    chart3_name="N/A"
    chart3 = ""

    layout_triple_chart(chart1,chart2,chart3,chart1_name,chart2_name,chart3_name)

    game = world_get_current_game(world)
    if game then
        puts_header "==游戏==",:level=>3
        puts "本月游戏名字=#{game[:name]}"
        puts "本月游戏代币=#{game[:token]}"
        puts "本月游戏上线时间=#{game[:launch_time]}"
        puts "本月游戏挖矿天数=#{game[:duration]}"
        puts "本月游戏总Token=#{game[:total_token]}"
        puts "本月游戏挖矿Token=#{game[:mining_token]}"
        puts "本月游戏空投Token=#{game[:airdrop_tokon]}"
        puts "本月游戏挖矿鱼数限制=#{game[:mining_limit]}"
        puts "本月游戏空投鱼数限制=#{game[:airdrop_limit]}"


        chart1_name="进入挖矿池 和 排队未进入的鱼比例"
        chart1 = pie_chart({"挖矿中"=>game[:mining_pool].size,"排队中"=>game[:mining_queue].size})

        chart2_name="游戏进入挖矿池 的 鱼等级分布"
        chart2 = column_chart(gen_dist(game[:mining_pool].map do |x| x[:level] end).to_h)

        chart3_name="游戏未进入挖矿池 的 鱼等级分布"
        chart3 = column_chart(gen_dist(game[:mining_queue].map do |x| x[:level] end).to_h)

        layout_triple_chart(chart1,chart2,chart3,chart1_name,chart2_name,chart3_name)

        puts_header "==用户==",:level=>3

        chart1_name="用户持有#{game[:token]}代表数量分布"
        chart1 = column_chart(gen_dist(world[:entity][:users].map do |x| 
            if x[:token]!=nil and x[:token][game[:token]] !=nil then
                x[:token][game[:token]] 
            else
                0
            end
        end ).to_h)
        chart2_name="N/A"
        chart2 = ""
        chart3_name="N/A"
        chart3 = ""
        layout_triple_chart(chart1,chart2,chart3,chart1_name,chart2_name,chart3_name)

    end
end





# -- time logic --

def world_next_day_mine_calc(world)
    game = world_get_current_game(world)
    return world if game==nil


    # update yield
    total_production = game[:mining_pool].map do |x| world_fish_get_production(world,x) end.sum
    total_token = game[:mining_token]
    production_rate = total_token.to_f / total_production.to_f

    token = game[:token]
    game[:mining_pool].each do |x| 
        world[:entity][:users].map! do |u| 
            if (u[:fishes].filter do |f| f[:fid]==x[:fid] end).size >0 then
               u[:token]={} if u[:token]==nil
               u[:token][token]=0 if u[:token][token]==nil
               u[:token][token]+= production_rate * world_fish_get_production(world,x)
            end;        
            u
        end
    end

    return world
end




