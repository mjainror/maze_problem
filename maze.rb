class Maze
  attr_reader :maze_file, :valid, :maze_start_x, :maze_start_y, :maze_end_x, :maze_end_y, :paths

  def initialize(file)
    @maze_file = file
    @valid = valid_file
    @paths = {}

    cells
  end

  def first_line
    @first_line ||= maze_file.gets
    @maze_size, @maze_start_x, @maze_start_y, @maze_end_x, @maze_end_y = @first_line.split(/\s/).map(&:to_i) if @first_line

    @first_line
  end

  def maze_size
    @maze_size.to_i
  end

  def maze_max_limit_x
    maze_size - 1
  end

  def maze_max_limit_y
    maze_size - 1
  end

  def valid_file
    !(first_line == nil)
  end

  def get_coordinates(line)
    if line[0...4] == "path"
      path, path_name, x, y, ds = line.split(/\s/,5)
      @paths[path_name.to_s] = { path_name: path_name, x: x.to_i, y: y.to_i, ds: ds.to_s.gsub!(/[^0-9A-Za-z]/, '') }

      return [] 
    end

    return line.split(/\s/,4)
  end

  def get_cells
    if !valid then return end

    cells_value = {}
    while line = maze_file.gets do
      x, y, ds, w = get_coordinates(line)
      w = w.to_s

      if x != nil && y != nil
        c_value = { x: x.to_i, y: y.to_i, direction: ds, weights: w }
        dss = ds.to_s.scan(/\w/)
        wts = w.to_s.split
        dss.each_with_index do |d, i|
          c_value[d] = wts[i].to_f       
        end
        cells_value[[x.to_i, y.to_i]] = c_value
      end
    end

    cells_value
  end

  def cells
    @cells ||= get_cells
  end

  def next_cell_x(current_x, current_y)
    return nil if (maze_size - 1) == current_x

    cells[[current_x + 1, current_y]]
  end

  def next_cell_y(current_x, current_y)
    return nil if (maze_size - 1) == current_y

    cells[[current_x, current_y + 1]]
  end

  def previous_cell_x(current_x, current_y)
    return nil if current_x < 0

    cells[[current_x - 1, current_y]]
  end

  def previous_cell_y(current_x, current_y)
    return nil if current_y < 0

    cells[[current_x, current_y - 1]]
  end

  def get_cell(x,y)
    cells[[x, y]]
  end

  def is_open?(cell, direction)
    cell[:direction].to_s.include?(direction) rescue false
  end

  def open_bridge_cells(x, y, direction = "l")
    cds = [get_cell(x,y)]

    2.times do
      cell = (direction == "l") ? next_cell_x(x, y) : next_cell_y(x, y)
      i_o = !is_open?(cell, direction)
      cds = [] if i_o
      break if i_o

      x, y = cell[:x], cell[:y]
      cds << cell
    end

    cds
  end

  def bridges
    bridge_cells = []

    ["l", "u"].each do |direction|
      for x in 0...maze_size
        for y in 0...maze_size
          a, b = direction == "u" ? [x, y] : [y, x]
          bridge_cells << open_bridge_cells(a, b, direction)
        end  
      end
    end

    bridge_cells.select{|bc| bc.size != 0}
  end

  def get_cells_for_i(x, y, i)
    cell = get_cell(x, y)

    is_cell = if i == 0
      cell == nil || cell[:direction] == "" || cell[:direction] == nil
    else
      cell != nil && cell[:direction] != "" && cell[:direction] != nil && cell[:direction].size == i
    end

    is_cell ? cell : nil
  end

  def get_sorted_cells(i)
    cells_for_i = []

    for x in 0...maze_size
      for y in 0...maze_size
        cells_for_i << get_cells_for_i(x, y, i)
      end  
    end

    cells_for_i.compact
  end

  def sorted_cells
    arr = []
    (0..4).each do |i|
      s_cells = get_sorted_cells(i)
      arr << "#{i},#{s_cells.map { |s| "(#{s[:x]},#{s[:y]})"}.join(",")}"
    end

    arr
  end

  def calculate_next_coordinate(x, y, ds)
    case ds.to_s
    when "u"
      [x, y - 1]
    when "d"
      [x, y + 1]
    when "l"
      [x - 1, y]
    when "r"
      [x + 1, y]
    else
      [x, y]
    end
  end

  def get_cells_and_weights(path)
    x, y = path[:x], path[:y]
    weights = []
    cls = []

    dss = path[:ds].to_s.gsub(/[^0-9A-Za-z]/, '').scan(/\w/)

    dss.each do |ds|
      cell = get_cell(x, y)
      cls << cell
      weights << cell[ds]

      x, y = calculate_next_coordinate(x, y, ds)
    end

    cls << get_cell(x, y)

    [cls, weights]
  end

  def get_path_weights
    path_weights = []
    paths.values.each do |path|
      cls, weights = get_cells_and_weights(path)
      weight = (weights.size == 0 || weights.size != weights.compact.size) ? nil : weights.compact.sum
      
      p_value = path
      p_value[:iterate_cells] = cls

      if weight == nil
        p_value = nil
      else
        p_value[:total_weight] = weight
      end
      
      path_weights << p_value
    end

    path_weights.compact
  end

  def get_shortest_path
    return @shortest_path if @shortest_path && @shortest_path.size > 0

    path_weights = get_path_weights
    if path_weights.compact.size == 0 then return nil end    

    @shortest_path = path_weights.compact.sort_by{|b| b[:total_weight]}.first
  end

  def get_paths
    path_weights = get_path_weights

    if path_weights.compact.size == 0 then return "none" end

    arr = []
    path_weights.compact.sort_by{|b| b[:total_weight]}.each do |p_weight|
      arr << "#{sprintf('%10.4f', p_weight[:total_weight])} #{p_weight[:path_name]}"
    end

    arr
  end

  def get_cell_parameter(x, y)
    is_on_path = get_shortest_path[:iterate_cells].select { |p| p[:x] == x && p[:y] == y }.size > 0 rescue false

    if maze_start_x == x && maze_start_y == y
      is_on_path ? "S" : "s"
    elsif maze_end_x == x && maze_end_y == y
      is_on_path ? "E" : "e"
    elsif is_on_path
      "*"
    else
      " "
    end
  end

  def solver
    cell_x = get_cell(maze_start_x, maze_start_y)
    cell_y = get_cell(maze_end_x, maze_end_y)
    cell_x[:direction] != nil && cell_x[:direction] != "" && cell_y[:direction] != nil && cell_y[:direction] != ""
  end

  def pretty_print
    str = ""
    for y in 0...maze_size
      y_value = { upper: "", middle: "", lower: "" }

      for x in 0...maze_size
        cell = get_cell(x, y)

        fillup_with = "udlr"

        if cell != nil && cell.size != 0
          dss = cell[:direction].to_s.scan(/\w/)
          dss.each{|ds| fillup_with.gsub!(ds, '')}
        end

        y_value[:middle] += (x == 0 || fillup_with.include?("l")) ? "|" : " "
        y_value[:middle] += get_cell_parameter(x, y)
        y_value[:middle] += "|\n" if (x == maze_size - 1)

        y_value[:upper] += (y == 0 || fillup_with.include?("u")) ? "+-" : "+ "
        y_value[:upper] += "+\n" if x == maze_size - 1

        y_value[:lower] += "+-" if y == maze_size - 1
        y_value[:lower] += "+" if y == maze_size - 1 && x == maze_size - 1
      end

      str += y_value.values.join
    end

    str
  end


  def get_traversed_values current_cell, p
    directions = current_cell[:direction].to_s.scan(/\w/)
    x, y = current_cell[:x], current_cell[:y]

    directions.each do |ds|
      cc = case ds
      when "u"
        previous_cell_y(x, y)
      when "d"
        next_cell_y(x, y)
      when "l"
        previous_cell_x(x, y)
      when "r"
        next_cell_x(x, y)
      end

      if @traversed.select{|e| e == [cc[:x], cc[:y]]}.size == 0
        @traversed.push([cc[:x], cc[:y]])
        @arr[p] ||= []
        @arr[p].push(cc)
      end
    end
  end
end

#----------------------------------
def main(command_name, file_name)
  maze_file = open(file_name)

  # perform command
  case command_name
  when "print"
    Maze.new(maze_file).pretty_print #read_and_print_simple_file(maze_file)
  when "bridge"
    Maze.new(maze_file).bridges.size
  when "sortcells"
    Maze.new(maze_file).sorted_cells
  when "paths"
    Maze.new(maze_file).get_paths
  when "solve"
    Maze.new(maze_file).solver
  else
    fail "Invalid command"
  end
end

