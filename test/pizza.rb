#!/usr/bin/env ruby

class Pizza
  attr_accessor :rows, :cols, :hams, :max, :matrix, :slices

  def self.parse(lines)
    p = Pizza.new
    p.rows, p.cols, p.hams, p.max = lines.shift.split.map(&:to_i)
    p.matrix = lines.map do |line|
      line.scan(/./).map { |c| c == 'H' }
    end
    p.slices = []
    p
  end

  def nb_hams(slice)
    nb = 0
    (slice[0]..slice[2]).each do |i|
      (slice[1]..slice[3]).each do |j|
        nb += 1 if matrix[i][j]
      end
    end
    nb
  end

  def cut(k = 2, start_row = 0, max_rows = rows)
    self.slices = []
    i = start_row
    while i+k <= max_rows
      j = 0
      l = max / k
      while j+l <= cols
        slice = [i, j, i + k - 1, j + l - 1]
        if nb_hams(slice) >= hams
          slices << slice
          j += l
        else
          j += 1
        end
      end
      i += k
    end
  end

  def best_cut
    best = []
    (rows / (max/2)).times do |l|
      start_row = l * max/2
      stop_row = start_row + max/2
      stop_row = rows if stop_row > rows
      best_slice_count = 0
      best_slices = nil

      (max/2).times do |k|
        cut(k + 1, start_row, stop_row)
        if slice_count > best_slice_count
          best_slice_count = slice_count
          best_slices = slices
        end
      end
      best.concat best_slices
    end
    self.slices = best
  end

  def output
    puts slice_count
    slices.each do |slice|
      puts slice.join(' ')
    end
  end

  def slice_count
    slices.count
  end
end

pizza = Pizza.parse ARGF.read.split("\n")
pizza.best_cut
pizza.output
