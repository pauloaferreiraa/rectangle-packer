#!/usr/bin/env ruby
# frozen_string_literal: true

TERM_COLS = 78
TERM_ROWS = 38

Piece  = Struct.new(:x, :y, :piece_width, :piece_height, :band, :grid_row, :grid_col, keyword_init: true)
Result = Struct.new(:count, :pieces, :strategy, :split_at, :split_axis, keyword_init: true)

class Packer
  def initialize(outer_width, outer_height, inner_width, inner_height)
    @outer_width  = outer_width.to_f
    @outer_height = outer_height.to_f
    @inner_width  = inner_width.to_f
    @inner_height = inner_height.to_f
  end

  def pack
    candidates = []
    record = ->(count, params) { candidates << [count, params] }

    record.(fit(@outer_width, @outer_height, @inner_width, @inner_height),
            { strategy: :uniform_a, piece_width: @inner_width, piece_height: @inner_height })
    record.(fit(@outer_width, @outer_height, @inner_height, @inner_width),
            { strategy: :uniform_b, piece_width: @inner_height, piece_height: @inner_width })

    h_splits.each do |split|
      both_orientations.each do |piece_w1, piece_h1|
        both_orientations.each do |piece_w2, piece_h2|
          count = fit(@outer_width, split, piece_w1, piece_h1) +
                  fit(@outer_width, @outer_height - split, piece_w2, piece_h2)
          record.(count, { strategy: :h_split, split: split,
                           piece_w1: piece_w1, piece_h1: piece_h1,
                           piece_w2: piece_w2, piece_h2: piece_h2 })
        end
      end
    end

    v_splits.each do |split|
      both_orientations.each do |piece_w1, piece_h1|
        both_orientations.each do |piece_w2, piece_h2|
          count = fit(split, @outer_height, piece_w1, piece_h1) +
                  fit(@outer_width - split, @outer_height, piece_w2, piece_h2)
          record.(count, { strategy: :v_split, split: split,
                           piece_w1: piece_w1, piece_h1: piece_h1,
                           piece_w2: piece_w2, piece_h2: piece_h2 })
        end
      end
    end

    best_count, best_params = candidates.max_by { |count, _| count } || [0, { strategy: :none }]
    build(best_count, best_params)
  end

  private

  def fit(area_width, area_height, piece_width, piece_height)
    return 0 if piece_width <= 0 || piece_height <= 0 || area_width < piece_width || area_height < piece_height
    (area_width / piece_width).floor * (area_height / piece_height).floor
  end

  def both_orientations
    [[@inner_width, @inner_height], [@inner_height, @inner_width]]
  end

  def candidate_splits(total_length, step1, step2)
    splits = []
    [step1, step2].each do |step|
      multiplier = 1
      loop do
        candidate = multiplier * step
        break if candidate >= total_length
        splits << candidate
        multiplier += 1
      end
    end
    splits.sort.uniq
  end

  def h_splits = candidate_splits(@outer_height, @inner_height, @inner_width)
  def v_splits = candidate_splits(@outer_width,  @inner_width,  @inner_height)

  def gen_pieces(area_width, area_height, piece_width, piece_height, band, offset_x: 0.0, offset_y: 0.0)
    col_count = (area_width  / piece_width).floor
    row_count = (area_height / piece_height).floor
    row_count.times.flat_map do |row|
      col_count.times.map do |col|
        Piece.new(
          x: offset_x + col * piece_width,
          y: offset_y + row * piece_height,
          piece_width:  piece_width,
          piece_height: piece_height,
          band:     band,
          grid_row: row,
          grid_col: col
        )
      end
    end
  end

  def build(count, params)
    pieces = case params[:strategy]
             when :uniform_a, :uniform_b
               gen_pieces(@outer_width, @outer_height, params[:piece_width], params[:piece_height], 0)
             when :h_split
               split = params[:split]
               gen_pieces(@outer_width, split, params[:piece_w1], params[:piece_h1], 1) +
                 gen_pieces(@outer_width, @outer_height - split, params[:piece_w2], params[:piece_h2], 2, offset_y: split)
             when :v_split
               split = params[:split]
               gen_pieces(split, @outer_height, params[:piece_w1], params[:piece_h1], 1) +
                 gen_pieces(@outer_width - split, @outer_height, params[:piece_w2], params[:piece_h2], 2, offset_x: split)
             else
               []
             end

    split_axis = { h_split: :h, v_split: :v }[params[:strategy]]
    Result.new(count: count, pieces: pieces, strategy: params[:strategy],
               split_at: params[:split], split_axis: split_axis)
  end
end

class Visualizer
  FILLS = %w[█ ▓].freeze
  WASTE  = '·'

  def initialize(outer_width, outer_height, inner_width, inner_height, result)
    @outer_width  = outer_width.to_f
    @outer_height = outer_height.to_f
    @inner_width  = inner_width.to_f
    @inner_height = inner_height.to_f
    @result = result
  end

  def render
    return nil if @result.count.zero?

    # Terminal chars are ~2x taller than wide; scale_x = 2 * scale_y preserves proportions
    scale_y = [TERM_COLS.to_f / (2.0 * @outer_width), TERM_ROWS.to_f / @outer_height].min
    scale_x = scale_y * 2.0

    canvas_cols = (@outer_width  * scale_x).round
    canvas_rows = (@outer_height * scale_y).round
    return nil if canvas_cols < 4 || canvas_rows < 2

    return nil if [@inner_width, @inner_height].min * scale_x < 1.0

    grid = Array.new(canvas_rows) { Array.new(canvas_cols, WASTE) }

    @result.pieces.each do |piece|
      char_left   = (piece.x                        * scale_x).round
      char_top    = (piece.y                        * scale_y).round
      char_right  = ((piece.x + piece.piece_width)  * scale_x).round
      char_bottom = ((piece.y + piece.piece_height) * scale_y).round
      fill = FILLS[(piece.grid_row + piece.grid_col) % 2]

      (char_top...[char_bottom, canvas_rows].min).each do |row|
        (char_left...[char_right, canvas_cols].min).each do |col|
          grid[row][col] = fill
        end
      end
    end

    if @result.split_axis == :h && @result.split_at
      split_row = (@result.split_at * scale_y).round
      grid[split_row] = Array.new(canvas_cols, '─') if split_row.between?(1, canvas_rows - 1)
    elsif @result.split_axis == :v && @result.split_at
      split_col = (@result.split_at * scale_x).round
      canvas_rows.times { |row| grid[row][split_col] = '│' } if split_col.between?(1, canvas_cols - 1)
    end

    # Piece dimension labels — written on top of the fill, centred inside each piece
    @result.pieces.each do |piece|
      char_left   = (piece.x                        * scale_x).round
      char_top    = (piece.y                        * scale_y).round
      char_right  = ((piece.x + piece.piece_width)  * scale_x).round
      char_bottom = ((piece.y + piece.piece_height) * scale_y).round
      piece_char_cols = char_right  - char_left
      piece_char_rows = char_bottom - char_top

      label = "#{fmt(piece.piece_width)}×#{fmt(piece.piece_height)}"
      next if piece_char_cols < label.length + 2 || piece_char_rows < 3

      label_col = char_left + (piece_char_cols - label.length) / 2
      label_row = char_top  + piece_char_rows / 2
      label.chars.each_with_index do |ch, i|
        col = label_col + i
        grid[label_row][col] = ch if label_row < canvas_rows && col.between?(0, canvas_cols - 1)
      end
    end

    # Box lines
    box_lines = [
      "┌#{'─' * canvas_cols}┐",
      *grid.map { |row| "│#{row.join}│" },
      "└#{'─' * canvas_cols}┘"
    ]

    # Height bracket on the right:  ╮ ... ─┤ 20 cm ... ╯
    height_label = "#{fmt(@outer_height)} cm"
    mid_idx      = (canvas_rows + 2) / 2
    lines = box_lines.map.with_index do |line, idx|
      suffix = if    idx == 0                    then ' ╮'
               elsif idx == box_lines.length - 1 then ' ╯'
               elsif idx == mid_idx              then "─┤ #{height_label}"
               else                                   ' │'
               end
      line + suffix
    end

    # Width arrow below:  ←──── 30 cm ────→
    width_label  = "#{fmt(@outer_width)} cm"
    total_width  = canvas_cols + 2        # box including corner chars
    dashes_total = total_width - width_label.length - 4  # reserve ← space label space →
    if dashes_total >= 2
      left_dashes  = dashes_total / 2
      right_dashes = dashes_total - left_dashes
      width_line   = "←#{'─' * left_dashes} #{width_label} #{'─' * right_dashes}→"
    else
      width_line = "← #{width_label} →"
    end

    [*lines, width_line].join("\n")
  end

  private

  def fmt(val)
    val.to_i == val ? val.to_i.to_s : val.round(2).to_s
  end
end

class SvgExporter
  MARGIN       = 1.0
  SW           = 0.05   # standard stroke-width in cm
  SW_THIN      = 0.03
  COLOR_BORDER = '#000000'
  COLOR_BAND1  = '#0066CC'
  COLOR_BAND2  = '#CC0000'
  COLOR_SPLIT  = '#999999'
  COLOR_DIM    = '#666666'
  FONT_PIECE   = 0.5
  FONT_DIM     = 0.45

  def initialize(outer_width, outer_height, result)
    @outer_width  = outer_width.to_f
    @outer_height = outer_height.to_f
    @result = result
  end

  def render
    doc_w = @outer_width  + 2 * MARGIN
    doc_h = @outer_height + 2 * MARGIN

    out = []
    out << '<?xml version="1.0" encoding="UTF-8"?>'
    out << %(<svg xmlns="http://www.w3.org/2000/svg" width="#{f(doc_w)}cm" height="#{f(doc_h)}cm" viewBox="0 0 #{f(doc_w)} #{f(doc_h)}">)

    # Outer boundary
    out << %(<rect x="#{f(MARGIN)}" y="#{f(MARGIN)}" width="#{f(@outer_width)}" height="#{f(@outer_height)}" fill="none" stroke="#{COLOR_BORDER}" stroke-width="#{SW}"/>)

    # Pieces
    @result.pieces.each do |piece|
      color = piece.band == 2 ? COLOR_BAND2 : COLOR_BAND1
      px = MARGIN + piece.x
      py = MARGIN + piece.y
      out << %(<rect x="#{f(px)}" y="#{f(py)}" width="#{f(piece.piece_width)}" height="#{f(piece.piece_height)}" fill="none" stroke="#{color}" stroke-width="#{SW}"/>)

      next unless piece.piece_width >= 1.5 && piece.piece_height >= 1.0
      label = "#{f(piece.piece_width)}×#{f(piece.piece_height)}"
      cx = px + piece.piece_width  / 2.0
      cy = py + piece.piece_height / 2.0
      out << %(<text x="#{f(cx)}" y="#{f(cy)}" text-anchor="middle" dominant-baseline="middle" font-family="sans-serif" font-size="#{FONT_PIECE}" fill="#{color}">#{label}</text>)
    end

    # Split line
    if @result.split_axis && @result.split_at
      if @result.split_axis == :h
        sy = MARGIN + @result.split_at
        out << %(<line x1="#{MARGIN}" y1="#{f(sy)}" x2="#{f(MARGIN + @outer_width)}" y2="#{f(sy)}" stroke="#{COLOR_SPLIT}" stroke-width="#{SW_THIN}" stroke-dasharray="0.2,0.15"/>)
      else
        sx = MARGIN + @result.split_at
        out << %(<line x1="#{f(sx)}" y1="#{MARGIN}" x2="#{f(sx)}" y2="#{f(MARGIN + @outer_height)}" stroke="#{COLOR_SPLIT}" stroke-width="#{SW_THIN}" stroke-dasharray="0.2,0.15"/>)
      end
    end

    # Width dimension: horizontal line + ticks below the outer rect
    x1    = MARGIN
    x2    = MARGIN + @outer_width
    y_dim = MARGIN + @outer_height + 0.55
    out << %(<line x1="#{f(x1)}" y1="#{f(y_dim)}" x2="#{f(x2)}" y2="#{f(y_dim)}" stroke="#{COLOR_DIM}" stroke-width="#{SW_THIN}"/>)
    [x1, x2].each do |tx|
      out << %(<line x1="#{f(tx)}" y1="#{f(y_dim - 0.2)}" x2="#{f(tx)}" y2="#{f(y_dim + 0.2)}" stroke="#{COLOR_DIM}" stroke-width="#{SW_THIN}"/>)
    end
    out << %(<text x="#{f((x1 + x2) / 2.0)}" y="#{f(y_dim + 0.35)}" text-anchor="middle" font-family="sans-serif" font-size="#{FONT_DIM}" fill="#{COLOR_DIM}">#{f(@outer_width)} cm</text>)

    # Height dimension: vertical line + ticks to the right of the outer rect
    y1    = MARGIN
    y2    = MARGIN + @outer_height
    x_dim = MARGIN + @outer_width + 0.55
    cy    = (y1 + y2) / 2.0
    out << %(<line x1="#{f(x_dim)}" y1="#{f(y1)}" x2="#{f(x_dim)}" y2="#{f(y2)}" stroke="#{COLOR_DIM}" stroke-width="#{SW_THIN}"/>)
    [y1, y2].each do |ty|
      out << %(<line x1="#{f(x_dim - 0.2)}" y1="#{f(ty)}" x2="#{f(x_dim + 0.2)}" y2="#{f(ty)}" stroke="#{COLOR_DIM}" stroke-width="#{SW_THIN}"/>)
    end
    out << %(<text x="#{f(x_dim + 0.35)}" y="#{f(cy)}" text-anchor="middle" dominant-baseline="middle" font-family="sans-serif" font-size="#{FONT_DIM}" fill="#{COLOR_DIM}" transform="rotate(90,#{f(x_dim + 0.35)},#{f(cy)})">#{f(@outer_height)} cm</text>)

    out << '</svg>'
    out.join("\n")
  end

  private

  def f(val)
    val.to_i == val ? val.to_i.to_s : val.round(4).to_s
  end
end

def prompt_float(label)
  print label
  $stdout.flush
  gets&.chomp.to_f
end

svg_mode = ARGV.delete('--svg')

outer_width, outer_height, inner_width, inner_height =
  if ARGV.size >= 4
    ARGV[0..3].map(&:to_f)
  else
    $stdout.puts "Rectangle Packer\n\n"
    [prompt_float("Outer width  (cm): "),
     prompt_float("Outer height (cm): "),
     prompt_float("Inner width  (cm): "),
     prompt_float("Inner height (cm): ")]
  end

if [outer_width, outer_height, inner_width, inner_height].any? { |v| v <= 0 }
  warn "Error: all dimensions must be positive numbers."
  exit 1
end

result = Packer.new(outer_width, outer_height, inner_width, inner_height).pack

if svg_mode
  if result.count.zero?
    warn "No pieces fit — the inner piece is larger than the outer in both orientations."
    exit 1
  end
  puts SvgExporter.new(outer_width, outer_height, result).render
  exit 0
end

puts
puts "Outer: #{outer_width}×#{outer_height} cm  |  Inner: #{inner_width}×#{inner_height} cm"
puts

if result.count.zero?
  puts "No pieces fit — the inner piece is larger than the outer in both orientations."
  exit 0
end

drawing = Visualizer.new(outer_width, outer_height, inner_width, inner_height, result).render
puts(drawing || "(Pieces too small to render at terminal scale)")
puts

fill_percent = (result.count * inner_width * inner_height * 100.0 / (outer_width * outer_height)).round(1)
waste_area   = (outer_width * outer_height - result.count * inner_width * inner_height).round(2)

strategy_labels = {
  uniform_a: 'grid — normal orientation',
  uniform_b: 'grid — rotated 90°',
  h_split:   'two-band horizontal split',
  v_split:   'two-band vertical split'
}

puts "Pieces : #{result.count}"
puts "Fill   : #{fill_percent}%"
puts "Waste  : #{waste_area} cm²"
puts "Layout : #{strategy_labels.fetch(result.strategy, result.strategy.to_s)}"
if result.split_at
  axis_name = result.split_axis == :h ? 'height' : 'width'
  puts "Split  : at #{result.split_at} cm (#{axis_name})"
end
