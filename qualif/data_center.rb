#!/usr/bin/env ruby

Server = Struct.new(:index, :size, :value, :row, :col, :group)
Row = Struct.new(:index, :size, :free, :cols)
Group = Struct.new(:index, :capacity, :servers)


class DataCenter
  attr_reader :lines, :rows, :cols, :occupied, :group_count
  attr_reader :grid
  attr_reader :servers
  attr_reader :groups

  def initialize(lines)
    @lines   = lines
    @grid    = []
    @servers = []

    parse_header
    parse_occupied
    parse_servers
  end

  def parse_header
    @rows, @cols, @occupied, @group_count, _ = lines[0].split.map(&:to_i)
    @grid = Array.new(rows) { |i| Row.new(i, cols, cols, Array.new(cols)) }
    @groups = Array.new(@group_count) { |i| Group.new(i, 0, []) }
  end

  def parse_occupied
    lines[1..occupied].each do |line|
      r, c = line.split.map(&:to_i)
      grid[r].cols[c] = :x
      grid[r].free -= 1
    end
  end

  def parse_servers
    lines[(occupied + 1)..lines.size].each_with_index do |line, idx|
      servers << Server.new(idx, *line.split.map(&:to_i))
    end
  end

  def magic
    servers.sort_by! { |s| [-1.0 * s.value / s.size, s.size] }
    servers.each do |server|
      place_server server
    end
    distribute_servers
    output
  end

  def place_server(server)
    grid.sort_by(&:free).each do |row|
      (row.size - server.size + 1).times do |i|
        can_be_placed = true
        server.size.times do |j|
          can_be_placed &&= row.cols[i+j] == nil
        end
        if can_be_placed
          server.size.times do |j|
            row.cols[i+j] = server.index
          end
          server.row = row.index
          server.col = i
          row.free -= server.size
          return row.index
        end
      end
    end
  end

  def placed_servers
    servers.select { |s| s.row && s.col }
  end

  def distribute_servers
    placed_servers.sort_by { |s| [-s.value, s.size] }.each do |server|
      group = groups.min_by do |g|
        c = g.servers.select { |s| s.row == server.row }.inject(0) { |a,s| a + s.value }
        g.capacity + c
      end
      server.group = group.index
      group.servers << server
      compute_capacity group
    end
  end

  def compute_capacity(group)
    group.capacity = rows.times.map do |i|
      servs = group.servers.select { |s| s.row != i }
      servs.inject(0) { |a,s| a + s.value }
    end.max
  end

  def output
    score = groups.map do |g|
      rows.times.map do |i|
        g.servers.select { |s| s.row != i }.inject(0) { |a,s| a + s.value }
      end.min
    end.min
    $stderr.puts "Score: #{score}"
    servers.sort_by(&:index).each do |server|
      if server.group
        puts "#{server.row} #{server.col} #{server.group}"
      else
        puts "x"
      end
    end
  end
end

DataCenter.new(ARGF.read.split("\n")).magic
