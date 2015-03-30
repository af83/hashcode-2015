#!/usr/bin/env ruby

NB_JOURNEYS = 200
NB_BEST = 3
TURNS_LAG = 3

class Area
  class << self
    attr_accessor :rows, :cols, :alts
    attr_accessor :targets, :winds     # winds [alt] [row] [col]
    attr_accessor :masks, :scores      # scores [row] [col]

    def compute_mask(radius)
      r2 = radius**2
      self.masks = []
      masks << [0, 0]
      (1..radius).each do |x|
        (1..radius).each do |y|
          masks << [x, y] << [-x, y] << [-x, -y] << [x, -y] if x**2 + y**2 < r2
        end
      end
    end

    def compute_scores
      self.scores = (0...rows).map do |i|
        (0...cols).map do |j|
          score_at(i, j)
        end
      end
    end

    def score_at(x, y)
      masks.inject(0) do |sum, mask|
        r = x + mask[0]
        c = (y + mask[1]) % Area.cols
        sum += targets[r][c] if r >= 0 && r < Area.rows
        sum
      end
    end
  end
end

Ball = Struct.new(:r, :c, :a) do
  class << self
    attr_accessor :radius
  end

  attr_accessor :dead, :strategy_name
  Strats = [
    :hotspot_strategy,
    :reverse_hotspot_strategy,
    :random_strategy,
  ].freeze

  def update_strategy(i)
    self.strategy_name = Strats[i % Strats.size]
  end

  def random_strategy
    rand(-1..1)
  end

  def reverse_hotspot_strategy
    if on_spot
      rand(0..1)
    else
      -1
    end
  end

  # Go down, winds are less strong at lower altitudes
  def hotspot_strategy
    if on_spot
      -1
    else
      rand(0..1)
    end
  end

  def strategy
    send strategy_name
  end

  def mean_score
    return @_avg if @_avg
    @_avg = Area.scores.map { |x| x.max }.reduce(:+) / Area.scores.count
  end

  def on_spot
    next_r = (r + Ball.radius) % Area.rows
    Area.scores[next_r][c] > mean_score / 4
  end

  # Change altitude of ballon
  def change_altitude(turn)
    return 0 if dead
    change = turn == 0 ? 1 : strategy

    change += 1 if a < 2 && change < 0
    change -= 1 if a > Area.alts - 2 && change > 0
    self.a += change
    wind = Area.winds[a][r][c]
    self.r += wind[0]
    self.c += wind[1]
    self.c %= Area.cols
    change
  end

  def alive?
    self.dead ||= r < 0 || r >= Area.rows
    !self.dead
  end

  def coverage(targets=Area.targets)
    min_c, max_c = c - Ball.radius, (c + Ball.radius) % Area.cols
    min_r, max_r = r - Ball.radius, r + Ball.radius
    targets.count do |u, v|
      u > min_r && u < max_r && v > min_c && v < max_c
    end
  end
end

Journey = Struct.new(:ball, :score, :hist) do
  def generate(turns, latitude)
    self.score = 0
    self.hist = []
    turns.times do |i|
      self.hist << ball.change_altitude(i)
      next unless ball.alive?
      s = Area.scores[ball.r][ball.c]
      s /= 2 if (latitude - ball.r).abs > Ball.radius
      self.score += s
    end
  end

  def delay(turns)
    self.hist = Array.new(turns, 0) + hist
  end
end

class Solver
  attr_accessor :nb_targets, :nb_balls, :turns, :ball, :balls

  def self.parse(lines)
    solver = new
    lines.map! { |line| line.split.map(&:to_i) }
    Area.rows, Area.cols, Area.alts = lines.shift
    solver.nb_targets, Ball.radius, solver.nb_balls, solver.turns = lines.shift
    solver.ball = Ball.new(*lines.shift, 0)
    solver.balls = solver.nb_balls.times do |i|
      solver.ball.clone
    end

    # Init target vector
    Area.targets = Array.new(Area.rows) { Array.new(Area.cols, 0) }
    solver.nb_targets.times do
      x, y = lines.shift
      Area.targets[x][y] += 1
    end
    Area.compute_mask(Ball.radius)
    Area.compute_scores

    # Init wind matrix
    Area.winds = []
    Area.alts.times do
      Area.winds << lines.shift(Area.rows).map { |l| l.each_slice(2).to_a }
    end

    solver
  end

  def magic
    sol = []
    best = []

    NB_BEST.times do |i|
      best << (0..NB_JOURNEYS).map do |journey_num|
        lat = Ball.radius * 2 * (i + 1)
        sample = ball.clone
        sample.update_strategy(journey_num)
        j = Journey.new(sample)
        j.generate(turns, lat)
        j
      end.max_by(&:score)
    end

    journeys = (0...nb_balls).map do |i|
      j = best[i % NB_BEST].clone
      j.delay(i % 2)
      j.delay(TURNS_LAG * i / NB_BEST)
      j
    end

    turns.times do |i|
      sol << nb_balls.times.map do |j|
        journeys[j].hist[i]
      end
    end

    sol
  end

  def output(solution)
    puts solution.map { |turn| turn.join(" ") }.join("\n")
  end
end

solver = Solver.parse ARGF.read.split("\n")
solver.output solver.magic
