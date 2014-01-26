module TeamsHelper
  def formatted_winning_percentage(pct_as_float)
    ('%.3f' % pct_as_float).sub('0.', '.')
  end

  def formatted_point_diff(point_diff)
    if point_diff > 0
      return "+#{point_diff}"
    end

    point_diff
  end
end
