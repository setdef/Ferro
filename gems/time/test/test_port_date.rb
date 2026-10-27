# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

#--
# SPDX-SnippetBegin
# SPDX-License-Identifier: MIT OR Apache-2.0
# SPDX-SnippetCopyrightText: Jacob Pratt et al.
# SPDX-SnippetComment: the test cases of time 0.3.55 tests/integration/date.rs
#++

# time's own tests in <tt>tests/integration/date.rs</tt>, ported: each
# method is the Rust test of the same name, with its cases. Cases that
# need a feature this gem leaves off (large-dates) or a type it defers
# (std's Duration) are left out, as the comments say.
class TestPortDate < Minitest::Test
  include TimeSuite

  # Asserts +actual+ is +expected+, which may be +nil+, as Rust's
  # +assert_eq!+ compares an +Option+.
  private def assert_case(expected, actual, message = nil)
    return assert_nil(actual, message) if expected.nil?

    assert_equal expected, actual, message
  end

  # The block's value, or +nil+ when it raises time's error, as Rust's
  # +Result::ok+ turns an +Err+ into +None+.
  private def ok
    yield
  rescue T::Error
    nil
  end

  # Names a deprecated method quietly, since the tests run under -w.
  private def quietly
    deprecated = Warning[:deprecated]
    Warning[:deprecated] = false
    yield
  ensure
    Warning[:deprecated] = deprecated
  end

  # <tt>date.rs:12</tt>, +debug+.
  def test_debug
    [
      [date(2020, 2, 3), "2020-02-03"],
    ].each do |date, expected|
      assert_case expected, date.inspect
    end
  end

  # <tt>date.rs:417</tt>, +weeks_in_year_exhaustive+.
  def test_weeks_in_year_exhaustive
    [
      [0, 52],
      [1, 52],
      [2, 52],
      [3, 52],
      [4, 53],
      [5, 52],
      [6, 52],
      [7, 52],
      [8, 52],
      [9, 53],
      [10, 52],
      [11, 52],
      [12, 52],
      [13, 52],
      [14, 52],
      [15, 53],
      [16, 52],
      [17, 52],
      [18, 52],
      [19, 52],
      [20, 53],
      [21, 52],
      [22, 52],
      [23, 52],
      [24, 52],
      [25, 52],
      [26, 53],
      [27, 52],
      [28, 52],
      [29, 52],
      [30, 52],
      [31, 52],
      [32, 53],
      [33, 52],
      [34, 52],
      [35, 52],
      [36, 52],
      [37, 53],
      [38, 52],
      [39, 52],
      [40, 52],
      [41, 52],
      [42, 52],
      [43, 53],
      [44, 52],
      [45, 52],
      [46, 52],
      [47, 52],
      [48, 53],
      [49, 52],
      [50, 52],
      [51, 52],
      [52, 52],
      [53, 52],
      [54, 53],
      [55, 52],
      [56, 52],
      [57, 52],
      [58, 52],
      [59, 52],
      [60, 53],
      [61, 52],
      [62, 52],
      [63, 52],
      [64, 52],
      [65, 53],
      [66, 52],
      [67, 52],
      [68, 52],
      [69, 52],
      [70, 52],
      [71, 53],
      [72, 52],
      [73, 52],
      [74, 52],
      [75, 52],
      [76, 53],
      [77, 52],
      [78, 52],
      [79, 52],
      [80, 52],
      [81, 52],
      [82, 53],
      [83, 52],
      [84, 52],
      [85, 52],
      [86, 52],
      [87, 52],
      [88, 53],
      [89, 52],
      [90, 52],
      [91, 52],
      [92, 52],
      [93, 53],
      [94, 52],
      [95, 52],
      [96, 52],
      [97, 52],
      [98, 52],
      [99, 53],
      [100, 52],
      [101, 52],
      [102, 52],
      [103, 52],
      [104, 52],
      [105, 53],
      [106, 52],
      [107, 52],
      [108, 52],
      [109, 52],
      [110, 52],
      [111, 53],
      [112, 52],
      [113, 52],
      [114, 52],
      [115, 52],
      [116, 53],
      [117, 52],
      [118, 52],
      [119, 52],
      [120, 52],
      [121, 52],
      [122, 53],
      [123, 52],
      [124, 52],
      [125, 52],
      [126, 52],
      [127, 52],
      [128, 53],
      [129, 52],
      [130, 52],
      [131, 52],
      [132, 52],
      [133, 53],
      [134, 52],
      [135, 52],
      [136, 52],
      [137, 52],
      [138, 52],
      [139, 53],
      [140, 52],
      [141, 52],
      [142, 52],
      [143, 52],
      [144, 53],
      [145, 52],
      [146, 52],
      [147, 52],
      [148, 52],
      [149, 52],
      [150, 53],
      [151, 52],
      [152, 52],
      [153, 52],
      [154, 52],
      [155, 52],
      [156, 53],
      [157, 52],
      [158, 52],
      [159, 52],
      [160, 52],
      [161, 53],
      [162, 52],
      [163, 52],
      [164, 52],
      [165, 52],
      [166, 52],
      [167, 53],
      [168, 52],
      [169, 52],
      [170, 52],
      [171, 52],
      [172, 53],
      [173, 52],
      [174, 52],
      [175, 52],
      [176, 52],
      [177, 52],
      [178, 53],
      [179, 52],
      [180, 52],
      [181, 52],
      [182, 52],
      [183, 52],
      [184, 53],
      [185, 52],
      [186, 52],
      [187, 52],
      [188, 52],
      [189, 53],
      [190, 52],
      [191, 52],
      [192, 52],
      [193, 52],
      [194, 52],
      [195, 53],
      [196, 52],
      [197, 52],
      [198, 52],
      [199, 52],
      [200, 52],
      [201, 53],
      [202, 52],
      [203, 52],
      [204, 52],
      [205, 52],
      [206, 52],
      [207, 53],
      [208, 52],
      [209, 52],
      [210, 52],
      [211, 52],
      [212, 53],
      [213, 52],
      [214, 52],
      [215, 52],
      [216, 52],
      [217, 52],
      [218, 53],
      [219, 52],
      [220, 52],
      [221, 52],
      [222, 52],
      [223, 52],
      [224, 53],
      [225, 52],
      [226, 52],
      [227, 52],
      [228, 52],
      [229, 53],
      [230, 52],
      [231, 52],
      [232, 52],
      [233, 52],
      [234, 52],
      [235, 53],
      [236, 52],
      [237, 52],
      [238, 52],
      [239, 52],
      [240, 53],
      [241, 52],
      [242, 52],
      [243, 52],
      [244, 52],
      [245, 52],
      [246, 53],
      [247, 52],
      [248, 52],
      [249, 52],
      [250, 52],
      [251, 52],
      [252, 53],
      [253, 52],
      [254, 52],
      [255, 52],
      [256, 52],
      [257, 53],
      [258, 52],
      [259, 52],
      [260, 52],
      [261, 52],
      [262, 52],
      [263, 53],
      [264, 52],
      [265, 52],
      [266, 52],
      [267, 52],
      [268, 53],
      [269, 52],
      [270, 52],
      [271, 52],
      [272, 52],
      [273, 52],
      [274, 53],
      [275, 52],
      [276, 52],
      [277, 52],
      [278, 52],
      [279, 52],
      [280, 53],
      [281, 52],
      [282, 52],
      [283, 52],
      [284, 52],
      [285, 53],
      [286, 52],
      [287, 52],
      [288, 52],
      [289, 52],
      [290, 52],
      [291, 53],
      [292, 52],
      [293, 52],
      [294, 52],
      [295, 52],
      [296, 53],
      [297, 52],
      [298, 52],
      [299, 52],
      [300, 52],
      [301, 52],
      [302, 52],
      [303, 53],
      [304, 52],
      [305, 52],
      [306, 52],
      [307, 52],
      [308, 53],
      [309, 52],
      [310, 52],
      [311, 52],
      [312, 52],
      [313, 52],
      [314, 53],
      [315, 52],
      [316, 52],
      [317, 52],
      [318, 52],
      [319, 52],
      [320, 53],
      [321, 52],
      [322, 52],
      [323, 52],
      [324, 52],
      [325, 53],
      [326, 52],
      [327, 52],
      [328, 52],
      [329, 52],
      [330, 52],
      [331, 53],
      [332, 52],
      [333, 52],
      [334, 52],
      [335, 52],
      [336, 53],
      [337, 52],
      [338, 52],
      [339, 52],
      [340, 52],
      [341, 52],
      [342, 53],
      [343, 52],
      [344, 52],
      [345, 52],
      [346, 52],
      [347, 52],
      [348, 53],
      [349, 52],
      [350, 52],
      [351, 52],
      [352, 52],
      [353, 53],
      [354, 52],
      [355, 52],
      [356, 52],
      [357, 52],
      [358, 52],
      [359, 53],
      [360, 52],
      [361, 52],
      [362, 52],
      [363, 52],
      [364, 53],
      [365, 52],
      [366, 52],
      [367, 52],
      [368, 52],
      [369, 52],
      [370, 53],
      [371, 52],
      [372, 52],
      [373, 52],
      [374, 52],
      [375, 52],
      [376, 53],
      [377, 52],
      [378, 52],
      [379, 52],
      [380, 52],
      [381, 53],
      [382, 52],
      [383, 52],
      [384, 52],
      [385, 52],
      [386, 52],
      [387, 53],
      [388, 52],
      [389, 52],
      [390, 52],
      [391, 52],
      [392, 53],
      [393, 52],
      [394, 52],
      [395, 52],
      [396, 52],
      [397, 52],
      [398, 53],
      [399, 52],
    ].each do |year, expected|
      assert_case expected, T::Util.weeks_in_year(year)
    end
  end

  # <tt>date.rs:586</tt>, +monday_based_week+.
  def test_monday_based_week
    [
      [date(2023, 1, 1), 0],
      [date(2023, 1, 2), 1],
      [date(2023, 1, 3), 1],
      [date(2023, 1, 4), 1],
      [date(2023, 1, 5), 1],
      [date(2023, 1, 6), 1],
      [date(2023, 1, 7), 1],
      [date(2022, 1, 1), 0],
      [date(2022, 1, 2), 0],
      [date(2022, 1, 3), 1],
      [date(2022, 1, 4), 1],
      [date(2022, 1, 5), 1],
      [date(2022, 1, 6), 1],
      [date(2022, 1, 7), 1],
      [date(2021, 1, 1), 0],
      [date(2021, 1, 2), 0],
      [date(2021, 1, 3), 0],
      [date(2021, 1, 4), 1],
      [date(2021, 1, 5), 1],
      [date(2021, 1, 6), 1],
      [date(2021, 1, 7), 1],
      [date(2026, 1, 1), 0],
      [date(2026, 1, 2), 0],
      [date(2026, 1, 3), 0],
      [date(2026, 1, 4), 0],
      [date(2026, 1, 5), 1],
      [date(2026, 1, 6), 1],
      [date(2026, 1, 7), 1],
      [date(2025, 1, 1), 0],
      [date(2025, 1, 2), 0],
      [date(2025, 1, 3), 0],
      [date(2025, 1, 4), 0],
      [date(2025, 1, 5), 0],
      [date(2025, 1, 6), 1],
      [date(2025, 1, 7), 1],
      [date(2019, 1, 1), 0],
      [date(2019, 1, 2), 0],
      [date(2019, 1, 3), 0],
      [date(2019, 1, 4), 0],
      [date(2019, 1, 5), 0],
      [date(2019, 1, 6), 0],
      [date(2019, 1, 7), 1],
      [date(2018, 1, 1), 1],
      [date(2018, 1, 2), 1],
      [date(2018, 1, 3), 1],
      [date(2018, 1, 4), 1],
      [date(2018, 1, 5), 1],
      [date(2018, 1, 6), 1],
      [date(2018, 1, 7), 1],
      [date(2012, 1, 1), 0],
      [date(2012, 1, 2), 1],
      [date(2012, 1, 3), 1],
      [date(2012, 1, 4), 1],
      [date(2012, 1, 5), 1],
      [date(2012, 1, 6), 1],
      [date(2012, 1, 7), 1],
      [date(2012, 2, 28), 9],
      [date(2012, 2, 29), 9],
      [date(2012, 3, 1), 9],
      [date(2012, 3, 2), 9],
      [date(2012, 3, 3), 9],
      [date(2012, 3, 4), 9],
      [date(2012, 3, 5), 10],
      [date(2012, 3, 6), 10],
      [date(2012, 3, 7), 10],
      [date(2028, 1, 1), 0],
      [date(2028, 1, 2), 0],
      [date(2028, 1, 3), 1],
      [date(2028, 1, 4), 1],
      [date(2028, 1, 5), 1],
      [date(2028, 1, 6), 1],
      [date(2028, 1, 7), 1],
      [date(2028, 2, 28), 9],
      [date(2028, 2, 29), 9],
      [date(2028, 3, 1), 9],
      [date(2028, 3, 2), 9],
      [date(2028, 3, 3), 9],
      [date(2028, 3, 4), 9],
      [date(2028, 3, 5), 9],
      [date(2028, 3, 6), 10],
      [date(2028, 3, 7), 10],
      [date(2016, 1, 1), 0],
      [date(2016, 1, 2), 0],
      [date(2016, 1, 3), 0],
      [date(2016, 1, 4), 1],
      [date(2016, 1, 5), 1],
      [date(2016, 1, 6), 1],
      [date(2016, 1, 7), 1],
      [date(2016, 2, 28), 8],
      [date(2016, 2, 29), 9],
      [date(2016, 3, 1), 9],
      [date(2016, 3, 2), 9],
      [date(2016, 3, 3), 9],
      [date(2016, 3, 4), 9],
      [date(2016, 3, 5), 9],
      [date(2016, 3, 6), 9],
      [date(2016, 3, 7), 10],
      [date(2032, 1, 1), 0],
      [date(2032, 1, 2), 0],
      [date(2032, 1, 3), 0],
      [date(2032, 1, 4), 0],
      [date(2032, 1, 5), 1],
      [date(2032, 1, 6), 1],
      [date(2032, 1, 7), 1],
      [date(2032, 2, 28), 8],
      [date(2032, 2, 29), 8],
      [date(2032, 3, 1), 9],
      [date(2032, 3, 2), 9],
      [date(2032, 3, 3), 9],
      [date(2032, 3, 4), 9],
      [date(2032, 3, 5), 9],
      [date(2032, 3, 6), 9],
      [date(2032, 3, 7), 9],
      [date(2020, 1, 1), 0],
      [date(2020, 1, 2), 0],
      [date(2020, 1, 3), 0],
      [date(2020, 1, 4), 0],
      [date(2020, 1, 5), 0],
      [date(2020, 1, 6), 1],
      [date(2020, 1, 7), 1],
      [date(2020, 2, 28), 8],
      [date(2020, 2, 29), 8],
      [date(2020, 3, 1), 8],
      [date(2020, 3, 2), 9],
      [date(2020, 3, 3), 9],
      [date(2020, 3, 4), 9],
      [date(2020, 3, 5), 9],
      [date(2020, 3, 6), 9],
      [date(2020, 3, 7), 9],
      [date(2036, 1, 1), 0],
      [date(2036, 1, 2), 0],
      [date(2036, 1, 3), 0],
      [date(2036, 1, 4), 0],
      [date(2036, 1, 5), 0],
      [date(2036, 1, 6), 0],
      [date(2036, 1, 7), 1],
      [date(2036, 2, 28), 8],
      [date(2036, 2, 29), 8],
      [date(2036, 3, 1), 8],
      [date(2036, 3, 2), 8],
      [date(2036, 3, 3), 9],
      [date(2036, 3, 4), 9],
      [date(2036, 3, 5), 9],
      [date(2036, 3, 6), 9],
      [date(2036, 3, 7), 9],
      [date(2024, 1, 1), 1],
      [date(2024, 1, 2), 1],
      [date(2024, 1, 3), 1],
      [date(2024, 1, 4), 1],
      [date(2024, 1, 5), 1],
      [date(2024, 1, 6), 1],
      [date(2024, 1, 7), 1],
      [date(2024, 2, 28), 9],
      [date(2024, 2, 29), 9],
      [date(2024, 3, 1), 9],
      [date(2024, 3, 2), 9],
      [date(2024, 3, 3), 9],
      [date(2024, 3, 4), 10],
      [date(2024, 3, 5), 10],
      [date(2024, 3, 6), 10],
      [date(2024, 3, 7), 10],
    ].each do |date, expected|
      assert_case expected, date.monday_based_week
    end
  end

  # <tt>date.rs:752</tt>, +sunday_based_week+.
  def test_sunday_based_week
    [
      [date(2023, 1, 1), 1],
      [date(2023, 1, 2), 1],
      [date(2023, 1, 3), 1],
      [date(2023, 1, 4), 1],
      [date(2023, 1, 5), 1],
      [date(2023, 1, 6), 1],
      [date(2023, 1, 7), 1],
      [date(2022, 1, 1), 0],
      [date(2022, 1, 2), 1],
      [date(2022, 1, 3), 1],
      [date(2022, 1, 4), 1],
      [date(2022, 1, 5), 1],
      [date(2022, 1, 6), 1],
      [date(2022, 1, 7), 1],
      [date(2021, 1, 1), 0],
      [date(2021, 1, 2), 0],
      [date(2021, 1, 3), 1],
      [date(2021, 1, 4), 1],
      [date(2021, 1, 5), 1],
      [date(2021, 1, 6), 1],
      [date(2021, 1, 7), 1],
      [date(2026, 1, 1), 0],
      [date(2026, 1, 2), 0],
      [date(2026, 1, 3), 0],
      [date(2026, 1, 4), 1],
      [date(2026, 1, 5), 1],
      [date(2026, 1, 6), 1],
      [date(2026, 1, 7), 1],
      [date(2025, 1, 1), 0],
      [date(2025, 1, 2), 0],
      [date(2025, 1, 3), 0],
      [date(2025, 1, 4), 0],
      [date(2025, 1, 5), 1],
      [date(2025, 1, 6), 1],
      [date(2025, 1, 7), 1],
      [date(2019, 1, 1), 0],
      [date(2019, 1, 2), 0],
      [date(2019, 1, 3), 0],
      [date(2019, 1, 4), 0],
      [date(2019, 1, 5), 0],
      [date(2019, 1, 6), 1],
      [date(2019, 1, 7), 1],
      [date(2018, 1, 1), 0],
      [date(2018, 1, 2), 0],
      [date(2018, 1, 3), 0],
      [date(2018, 1, 4), 0],
      [date(2018, 1, 5), 0],
      [date(2018, 1, 6), 0],
      [date(2018, 1, 7), 1],
      [date(2012, 1, 1), 1],
      [date(2012, 1, 2), 1],
      [date(2012, 1, 3), 1],
      [date(2012, 1, 4), 1],
      [date(2012, 1, 5), 1],
      [date(2012, 1, 6), 1],
      [date(2012, 1, 7), 1],
      [date(2012, 2, 28), 9],
      [date(2012, 2, 29), 9],
      [date(2012, 3, 1), 9],
      [date(2012, 3, 2), 9],
      [date(2012, 3, 3), 9],
      [date(2012, 3, 4), 10],
      [date(2012, 3, 5), 10],
      [date(2012, 3, 6), 10],
      [date(2012, 3, 7), 10],
      [date(2028, 1, 1), 0],
      [date(2028, 1, 2), 1],
      [date(2028, 1, 3), 1],
      [date(2028, 1, 4), 1],
      [date(2028, 1, 5), 1],
      [date(2028, 1, 6), 1],
      [date(2028, 1, 7), 1],
      [date(2028, 2, 28), 9],
      [date(2028, 2, 29), 9],
      [date(2028, 3, 1), 9],
      [date(2028, 3, 2), 9],
      [date(2028, 3, 3), 9],
      [date(2028, 3, 4), 9],
      [date(2028, 3, 5), 10],
      [date(2028, 3, 6), 10],
      [date(2028, 3, 7), 10],
      [date(2016, 1, 1), 0],
      [date(2016, 1, 2), 0],
      [date(2016, 1, 3), 1],
      [date(2016, 1, 4), 1],
      [date(2016, 1, 5), 1],
      [date(2016, 1, 6), 1],
      [date(2016, 1, 7), 1],
      [date(2016, 2, 28), 9],
      [date(2016, 2, 29), 9],
      [date(2016, 3, 1), 9],
      [date(2016, 3, 2), 9],
      [date(2016, 3, 3), 9],
      [date(2016, 3, 4), 9],
      [date(2016, 3, 5), 9],
      [date(2016, 3, 6), 10],
      [date(2016, 3, 7), 10],
      [date(2032, 1, 1), 0],
      [date(2032, 1, 2), 0],
      [date(2032, 1, 3), 0],
      [date(2032, 1, 4), 1],
      [date(2032, 1, 5), 1],
      [date(2032, 1, 6), 1],
      [date(2032, 1, 7), 1],
      [date(2032, 2, 28), 8],
      [date(2032, 2, 29), 9],
      [date(2032, 3, 1), 9],
      [date(2032, 3, 2), 9],
      [date(2032, 3, 3), 9],
      [date(2032, 3, 4), 9],
      [date(2032, 3, 5), 9],
      [date(2032, 3, 6), 9],
      [date(2032, 3, 7), 10],
      [date(2020, 1, 1), 0],
      [date(2020, 1, 2), 0],
      [date(2020, 1, 3), 0],
      [date(2020, 1, 4), 0],
      [date(2020, 1, 5), 1],
      [date(2020, 1, 6), 1],
      [date(2020, 1, 7), 1],
      [date(2020, 2, 28), 8],
      [date(2020, 2, 29), 8],
      [date(2020, 3, 1), 9],
      [date(2020, 3, 2), 9],
      [date(2020, 3, 3), 9],
      [date(2020, 3, 4), 9],
      [date(2020, 3, 5), 9],
      [date(2020, 3, 6), 9],
      [date(2020, 3, 7), 9],
      [date(2036, 1, 1), 0],
      [date(2036, 1, 2), 0],
      [date(2036, 1, 3), 0],
      [date(2036, 1, 4), 0],
      [date(2036, 1, 5), 0],
      [date(2036, 1, 6), 1],
      [date(2036, 1, 7), 1],
      [date(2036, 2, 28), 8],
      [date(2036, 2, 29), 8],
      [date(2036, 3, 1), 8],
      [date(2036, 3, 2), 9],
      [date(2036, 3, 3), 9],
      [date(2036, 3, 4), 9],
      [date(2036, 3, 5), 9],
      [date(2036, 3, 6), 9],
      [date(2036, 3, 7), 9],
      [date(2024, 1, 1), 0],
      [date(2024, 1, 2), 0],
      [date(2024, 1, 3), 0],
      [date(2024, 1, 4), 0],
      [date(2024, 1, 5), 0],
      [date(2024, 1, 6), 0],
      [date(2024, 1, 7), 1],
      [date(2024, 2, 28), 8],
      [date(2024, 2, 29), 8],
      [date(2024, 3, 1), 8],
      [date(2024, 3, 2), 8],
      [date(2024, 3, 3), 9],
      [date(2024, 3, 4), 9],
      [date(2024, 3, 5), 9],
      [date(2024, 3, 6), 9],
      [date(2024, 3, 7), 9],
    ].each do |date, expected|
      assert_case expected, date.sunday_based_week
    end
  end

  # <tt>date.rs:761</tt>, +from_iso_week_date_ok+.
  def test_from_iso_week_date_ok
    [
      [2019, 1, Weekday::Monday],
      [2019, 1, Weekday::Tuesday],
      [2020, 53, Weekday::Friday],
      [-9999, 1, Weekday::Monday],
    ].each do |year, week, weekday|
      T::Date.from_iso_week_date(year, week, weekday)
    end
  end

  # <tt>date.rs:768</tt>, +from_iso_week_date_err+.
  def test_from_iso_week_date_err
    [
      [2019, 53, Weekday::Monday],
      [999999, 52, Weekday::Saturday],
    ].each do |year, week, weekday|
      assert_raises(T::Error::ComponentRange) { T::Date.from_iso_week_date(year, week, weekday) }
    end
  end

  # <tt>date.rs:773</tt>, +from_iso_week_date_regression+. Year zero (1
  # BCE) has dominical letter BA.
  def test_from_iso_week_date_regression
    assert_equal date(0, 1, 1), T::Date.from_iso_week_date(-1, 52, Weekday::Saturday)
  end

  # <tt>date.rs:785</tt>, +year+.
  def test_year
    [
      [T::Date.from_ordinal_date(2019, 2), 2019],
      [T::Date.from_ordinal_date(2020, 2), 2020],
    ].each do |date, expected|
      assert_case expected, date.year
    end
  end

  # <tt>date.rs:794</tt>, +month+.
  def test_month
    [
      [T::Date.from_ordinal_date(2019, 2), Month::January],
      [T::Date.from_ordinal_date(2020, 2), Month::January],
      [T::Date.from_ordinal_date(2019, 60), Month::March],
      [T::Date.from_ordinal_date(2020, 60), Month::February],
    ].each do |date, expected|
      assert_case expected, date.month
    end
  end

  # <tt>date.rs:803</tt>, +day+.
  def test_day
    [
      [T::Date.from_ordinal_date(2019, 2), 2],
      [T::Date.from_ordinal_date(2020, 2), 2],
      [T::Date.from_ordinal_date(2019, 60), 1],
      [T::Date.from_ordinal_date(2020, 60), 29],
    ].each do |date, expected|
      assert_case expected, date.day
    end
  end

  # <tt>date.rs:813</tt>, +iso_week+.
  def test_iso_week
    [
      [date(2019, 1, 1), 1],
      [date(2019, 10, 4), 40],
      [date(2020, 1, 1), 1],
      [date(2020, 12, 31), 53],
      [date(2021, 1, 1), 53],
    ].each do |date, expected|
      assert_case expected, date.iso_week
    end
  end

  # <tt>date.rs:829</tt>, +to_calendar_date+.
  def test_to_calendar_date
    [
      [date(2019, 1, 2), [2019, Month::January, 2]],
      [date(2019, 2, 2), [2019, Month::February, 2]],
      [date(2019, 3, 2), [2019, Month::March, 2]],
      [date(2019, 4, 2), [2019, Month::April, 2]],
      [date(2019, 5, 2), [2019, Month::May, 2]],
      [date(2019, 6, 2), [2019, Month::June, 2]],
      [date(2019, 7, 2), [2019, Month::July, 2]],
      [date(2019, 8, 2), [2019, Month::August, 2]],
      [date(2019, 9, 2), [2019, Month::September, 2]],
      [date(2019, 10, 2), [2019, Month::October, 2]],
      [date(2019, 11, 2), [2019, Month::November, 2]],
      [date(2019, 12, 2), [2019, Month::December, 2]],
    ].each do |date, expected|
      assert_case expected, date.to_calendar_date
    end
  end

  # <tt>date.rs:835</tt>, +to_ordinal_date+.
  def test_to_ordinal_date
    [
      [date(2019, 1, 1), [2019, 1]],
    ].each do |date, expected|
      assert_case expected, date.to_ordinal_date
    end
  end

  # <tt>date.rs:845</tt>, +to_iso_week_date+.
  def test_to_iso_week_date
    [
      [date(2019, 1, 1), [2019, 1, Weekday::Tuesday]],
      [date(2019, 10, 4), [2019, 40, Weekday::Friday]],
      [date(2020, 1, 1), [2020, 1, Weekday::Wednesday]],
      [date(2020, 12, 31), [2020, 53, Weekday::Thursday]],
      [date(2021, 1, 1), [2020, 53, Weekday::Friday]],
      [date(0, 1, 1), [-1, 52, Weekday::Saturday]],
    ].each do |date, expected|
      assert_case expected, date.to_iso_week_date
    end
  end

  # <tt>date.rs:862</tt>, +weekday+.
  def test_weekday
    [
      [date(2019, 1, 1), Weekday::Tuesday],
      [date(2019, 2, 1), Weekday::Friday],
      [date(2019, 3, 1), Weekday::Friday],
      [date(2019, 4, 1), Weekday::Monday],
      [date(2019, 5, 1), Weekday::Wednesday],
      [date(2019, 6, 1), Weekday::Saturday],
      [date(2019, 7, 1), Weekday::Monday],
      [date(2019, 8, 1), Weekday::Thursday],
      [date(2019, 9, 1), Weekday::Sunday],
      [date(2019, 10, 1), Weekday::Tuesday],
      [date(2019, 11, 1), Weekday::Friday],
      [date(2019, 12, 1), Weekday::Sunday],
    ].each do |date, expected|
      assert_case expected, date.weekday
    end
  end

  # <tt>date.rs:872</tt>, +next_day+.
  def test_next_day
    [
      [date(2019, 1, 1), date(2019, 1, 2)],
      [date(2019, 1, 31), date(2019, 2, 1)],
      [date(2019, 12, 31), date(2020, 1, 1)],
      [date(2020, 12, 31), date(2021, 1, 1)],
      [T::Date::MAX, nil],
    ].each do |date, expected|
      assert_case expected, date.next_day
    end
  end

  # <tt>date.rs:882</tt>, +previous_day+.
  def test_previous_day
    [
      [date(2019, 1, 2), date(2019, 1, 1)],
      [date(2019, 2, 1), date(2019, 1, 31)],
      [date(2020, 1, 1), date(2019, 12, 31)],
      [date(2021, 1, 1), date(2020, 12, 31)],
      [T::Date::MIN, nil],
    ].each do |date, expected|
      assert_case expected, date.previous_day
    end
  end

  # <tt>date.rs:893</tt>, +to_julian_day+.
  def test_to_julian_day
    [
      [date(-9999, 1, 1), -1_930_999],
      [date(-4713, 11, 24), 0],
      [date(2000, 1, 1), 2_451_545],
      [date(2019, 1, 1), 2_458_485],
      [date(2019, 12, 31), 2_458_849],
      # left out: large-dates year -999_999
    ].each do |date, expected|
      assert_case expected, date.to_julian_day
    end
  end

  # <tt>date.rs:904</tt>, +from_julian_day+.
  def test_from_julian_day
    [
      [-1_930_999, date(-9999, 1, 1)],
      [0, date(-4713, 11, 24)],
      [2_451_545, date(2000, 1, 1)],
      [2_458_485, date(2019, 1, 1)],
      [2_458_849, date(2019, 12, 31)],
      [((2 ** 31) - 1), nil],
      # left out: large-dates year -999_999
    ].each do |julian_day, expected|
      if expected.nil?
        assert_raises(T::Error::ComponentRange) { T::Date.from_julian_day(julian_day) }
      else
        assert_case expected, T::Date.from_julian_day(julian_day)
      end
    end
  end

  # <tt>date.rs:916</tt>, +midnight+.
  def test_midnight
    [
      [date(1970, 1, 1), date(1970, 1, 1).with_hms_nano(0, 0, 0, 0)],
      [date(2023, 6, 15), date(2023, 6, 15).with_hms_nano(0, 0, 0, 0)],
      [date(2000, 1, 1), date(2000, 1, 1).with_hms_nano(0, 0, 0, 0)],
    ].each do |date, expected|
      assert_case expected, date.midnight
    end
  end

  # <tt>date.rs:922</tt>, +with_time+.
  def test_with_time
    [
      [date(1970, 1, 1), clock(0, 0, 0, 0), date(1970, 1, 1).with_hms_nano(0, 0, 0, 0)],
    ].each do |date, time_value, expected|
      assert_case expected, date.with_time(time_value)
    end
  end

  # <tt>date.rs:929</tt>, +with_hms+.
  def test_with_hms
    [
      [0, 0, 0, date(1970, 1, 1).with_hms_nano(0, 0, 0, 0)],
      [24, 0, 0, nil],
    ].each do |hour, minute, second, expected|
      date = date(1970, 1, 1)
      if expected.nil?
        assert_raises(T::Error::ComponentRange) { date.with_hms(hour, minute, second) }
      else
        assert_case expected, date.with_hms(hour, minute, second)
      end
    end
  end

  # <tt>date.rs:947</tt>, +with_hms_milli+.
  def test_with_hms_milli
    [
      [0, 0, 0, 0, date(1970, 1, 1).with_hms_nano(0, 0, 0, 0)],
      [24, 0, 0, 0, nil],
    ].each do |hour, minute, second, fraction, expected|
      date = date(1970, 1, 1)
      if expected.nil?
        assert_raises(T::Error::ComponentRange) { date.with_hms_milli(hour, minute, second, fraction) }
      else
        assert_case expected, date.with_hms_milli(hour, minute, second, fraction)
      end
    end
  end

  # <tt>date.rs:966</tt>, +with_hms_micro+.
  def test_with_hms_micro
    [
      [0, 0, 0, 0, date(1970, 1, 1).with_hms_nano(0, 0, 0, 0)],
      [24, 0, 0, 0, nil],
    ].each do |hour, minute, second, fraction, expected|
      date = date(1970, 1, 1)
      if expected.nil?
        assert_raises(T::Error::ComponentRange) { date.with_hms_micro(hour, minute, second, fraction) }
      else
        assert_case expected, date.with_hms_micro(hour, minute, second, fraction)
      end
    end
  end

  # <tt>date.rs:985</tt>, +with_hms_nano+.
  def test_with_hms_nano
    [
      [0, 0, 0, 0, date(1970, 1, 1).with_hms_nano(0, 0, 0, 0)],
      [24, 0, 0, 0, nil],
    ].each do |hour, minute, second, fraction, expected|
      date = date(1970, 1, 1)
      if expected.nil?
        assert_raises(T::Error::ComponentRange) { date.with_hms_nano(hour, minute, second, fraction) }
      else
        assert_case expected, date.with_hms_nano(hour, minute, second, fraction)
      end
    end
  end

  # <tt>date.rs:1004</tt>, +add+.
  def test_add
    [
      [date(2019, 1, 1), Duration.days(5), date(2019, 1, 6)],
      [date(2019, 12, 31), Duration.days(1), date(2020, 1, 1)],
    ].each do |date, duration, expected|
      assert_case expected, date + duration
    end
  end

  # <tt>date.rs:1017</tt>, +add_assign+.
  def test_add_assign
    [
      [date(2019, 12, 31), Duration.days(1), date(2020, 1, 1)],
    ].each do |date, duration, expected|
      date += duration
      assert_case expected, date
    end
  end

  # <tt>date.rs:1034</tt>, +sub+.
  def test_sub
    [
      [date(2019, 1, 6), Duration.days(5), date(2019, 1, 1)],
      [date(2020, 1, 1), Duration.days(1), date(2019, 12, 31)],
    ].each do |date, duration, expected|
      assert_case expected, date - duration
    end
  end

  # <tt>date.rs:1047</tt>, +sub_assign+.
  def test_sub_assign
    [
      [date(2020, 1, 1), Duration.days(1), date(2019, 12, 31)],
    ].each do |date, duration, expected|
      date -= duration
      assert_case expected, date
    end
  end

  # <tt>date.rs:1064</tt>, +sub_self+.
  def test_sub_self
    [
      [date(2019, 1, 6), date(2019, 1, 1), Duration.days(5)],
      [date(2020, 1, 1), date(2019, 12, 31), Duration.days(1)],
    ].each do |a, b, expected|
      assert_case expected, a - b
    end
  end

  # <tt>date.rs:1070</tt>, +partial_ord+.
  def test_partial_ord
    [
      [date(2019, 1, 1), date(2019, 1, 2)],
    ].each do |first, second|
      assert_equal 0, first <=> first
      assert_equal(-1, first <=> second)
      assert_equal 1, second <=> first
    end
  end

  # <tt>date.rs:1078</tt>, +ord+.
  def test_ord
    [
      [date(2019, 1, 1), date(2019, 1, 2)],
    ].each do |first, second|
      assert_equal 0, first <=> first
      assert_equal(-1, first <=> second)
      assert_equal 1, second <=> first
    end
  end

  # <tt>date.rs:1085</tt>, +regression_check+.
  def test_regression_check
    year, week, weekday = T::Date.from_ordinal_date(63, 365).to_iso_week_date
    assert_equal 64, year
    assert_equal 1, week
    assert_equal Weekday::Monday, weekday
  end

  # <tt>date.rs:1107</tt>, +checked_add_duration+.
  def test_checked_add_duration
    [
      [T::Date::MIN, Duration.new(86_399, 999_999_999), T::Date::MIN],
      [T::Date::MIN, Duration.new(-86_399, -999_999_999), T::Date::MIN],
      [date(2021, 10, 25), Duration.new(86_399, 999_999_999), date(2021, 10, 25)],
      [date(2021, 10, 25), Duration.new(-86_399, -999_999_999), date(2021, 10, 25)],
      [T::Date::MAX, Duration.new(86_399, 999_999_999), T::Date::MAX],
      [T::Date::MAX, Duration.new(-86_399, -999_999_999), T::Date::MAX],
      [T::Date::MIN, Duration::DAY, T::Date::MIN.next_day],
      [T::Date::MIN, -Duration::DAY, nil],
      [date(2021, 10, 25), Duration::DAY, date(2021, 10, 26)],
      [date(2021, 10, 25), -Duration::DAY, date(2021, 10, 24)],
      [T::Date::MAX, Duration::DAY, nil],
      [T::Date::MAX, -Duration::DAY, T::Date::MAX.previous_day],
      [T::Date::MIN, Duration::MIN, nil],
      [T::Date::MAX, Duration::MAX, nil],
    ].each do |date, duration, expected|
      assert_case expected, date.checked_add(duration)
    end
  end

  # <tt>date.rs:1130</tt>, +checked_sub_duration+.
  def test_checked_sub_duration
    [
      [T::Date::MIN, Duration.new(86_399, 999_999_999), T::Date::MIN],
      [T::Date::MIN, Duration.new(-86_399, -999_999_999), T::Date::MIN],
      [date(2021, 10, 25), Duration.new(86_399, 999_999_999), date(2021, 10, 25)],
      [date(2021, 10, 25), Duration.new(-86_399, -999_999_999), date(2021, 10, 25)],
      [T::Date::MAX, Duration.new(86_399, 999_999_999), T::Date::MAX],
      [T::Date::MAX, Duration.new(-86_399, -999_999_999), T::Date::MAX],
      [T::Date::MIN, Duration::DAY, nil],
      [T::Date::MIN, -Duration::DAY, T::Date::MIN.next_day],
      [date(2021, 10, 25), Duration::DAY, date(2021, 10, 24)],
      [date(2021, 10, 25), -Duration::DAY, date(2021, 10, 26)],
      [T::Date::MAX, Duration::DAY, T::Date::MAX.previous_day],
      [T::Date::MAX, -Duration::DAY, nil],
      [T::Date::MIN, Duration::MAX, nil],
      [T::Date::MAX, Duration::MIN, nil],
    ].each do |date, duration, expected|
      assert_case expected, date.checked_sub(duration)
    end
  end

  # <tt>date.rs:1145</tt>, +saturating_add_duration+.
  def test_saturating_add_duration
    [
      [date(2021, 11, 5), Duration.days(2), date(2021, 11, 7)],
      [date(2021, 11, 5), Duration.days(-2), date(2021, 11, 3)],
      [T::Date::MIN, Duration.days(-10), T::Date::MIN],
      [T::Date::MAX, Duration.days(10), T::Date::MAX],
      [T::Date::MIN, Duration::ZERO, T::Date::MIN],
      [T::Date::MAX, Duration::ZERO, T::Date::MAX],
    ].each do |date, duration, expected|
      assert_case expected, date.saturating_add(duration)
    end
  end

  # <tt>date.rs:1160</tt>, +saturating_sub_duration+.
  def test_saturating_sub_duration
    [
      [date(2021, 11, 5), Duration.days(2), date(2021, 11, 3)],
      [date(2021, 11, 5), Duration.days(-2), date(2021, 11, 7)],
      [T::Date::MIN, Duration.days(10), T::Date::MIN],
      [T::Date::MAX, Duration.days(-10), T::Date::MAX],
      [T::Date::MIN, Duration::ZERO, T::Date::MIN],
      [T::Date::MAX, Duration::ZERO, T::Date::MAX],
    ].each do |date, duration, expected|
      assert_case expected, date.saturating_sub(duration)
    end
  end

  # <tt>date.rs:1179</tt>, +replace_year+.
  def test_replace_year
    [
      [date(2022, 2, 18), 2019, date(2019, 2, 18)],
      [date(2022, 2, 18), -1_000_000_000, nil],
      [date(2022, 2, 18), 1_000_000_000, nil],
      [date(2022, 1, 1), 2024, date(2024, 1, 1)],
      [date(2022, 12, 1), 2024, date(2024, 12, 1)],
      [date(2024, 1, 1), 2022, date(2022, 1, 1)],
      [date(2024, 12, 1), 2022, date(2022, 12, 1)],
      [date(2024, 2, 29), 2022, nil],
      [date(2022, 12, 1), 2023, date(2023, 12, 1)],
      [date(2024, 12, 1), 2028, date(2028, 12, 1)],
    ].each do |date, year, expected|
      if expected.nil?
        assert_raises(T::Error::ComponentRange) { date.replace_year(year) }
      else
        assert_case expected, date.replace_year(year)
      end
    end
  end

  # <tt>date.rs:1190</tt>, +replace_month+.
  def test_replace_month
    [
      [date(2022, 2, 18), Month::January, date(2022, 1, 18)],
      [date(2022, 1, 30), Month::February, nil],
    ].each do |date, month, expected|
      if expected.nil?
        assert_raises(T::Error::ComponentRange) { date.replace_month(month) }
      else
        assert_case expected, date.replace_month(month)
      end
    end
  end

  # <tt>date.rs:1206</tt>, +replace_day+.
  def test_replace_day
    [
      [date(2022, 2, 18), 1, date(2022, 2, 1)],
      [date(2022, 2, 18), 0, nil],
      [date(2022, 2, 18), 30, nil],
    ].each do |date, day, expected|
      if expected.nil?
        assert_raises(T::Error::ComponentRange) { date.replace_day(day) }
      else
        assert_case expected, date.replace_day(day)
      end
    end
  end

  # <tt>date.rs:1220</tt>, +replace_ordinal+.
  def test_replace_ordinal
    [
      [date(2022, 2, 18), 1, T::Date.from_ordinal_date(2022, 1)],
      [date(2024, 2, 29), 366, T::Date.from_ordinal_date(2024, 366)],
      [T::Date.from_ordinal_date(2022, 49), 0, nil],
      [T::Date.from_ordinal_date(2022, 49), 366, nil],
      [T::Date.from_ordinal_date(2022, 49), 367, nil],
    ].each do |date, ordinal, expected|
      if expected.nil?
        assert_raises(T::Error::ComponentRange) { date.replace_ordinal(ordinal) }
      else
        assert_case expected, date.replace_ordinal(ordinal)
      end
    end
  end

  # <tt>date.rs:1242</tt>, +next_occurrence_test+.
  def test_next_occurrence_test
    [
      [date(2023, 6, 25), Weekday::Monday, date(2023, 6, 26)],
      [date(2023, 6, 26), Weekday::Monday, date(2023, 7, 3)],
      [date(2023, 6, 27), Weekday::Monday, date(2023, 7, 3)],
      [date(2023, 6, 28), Weekday::Monday, date(2023, 7, 3)],
      [date(2023, 6, 29), Weekday::Monday, date(2023, 7, 3)],
      [date(2023, 6, 30), Weekday::Monday, date(2023, 7, 3)],
      [date(2023, 7, 1), Weekday::Monday, date(2023, 7, 3)],
      [date(2023, 7, 2), Weekday::Monday, date(2023, 7, 3)],
      [date(2023, 7, 3), Weekday::Monday, date(2023, 7, 10)],
    ].each do |date, weekday, expected|
      assert_case expected, date.next_occurrence(weekday)
    end
  end

  # <tt>date.rs:1256</tt>, +prev_occurrence_test+.
  def test_prev_occurrence_test
    [
      [date(2023, 7, 7), Weekday::Thursday, date(2023, 7, 6)],
      [date(2023, 7, 6), Weekday::Thursday, date(2023, 6, 29)],
      [date(2023, 7, 5), Weekday::Thursday, date(2023, 6, 29)],
      [date(2023, 7, 4), Weekday::Thursday, date(2023, 6, 29)],
      [date(2023, 7, 3), Weekday::Thursday, date(2023, 6, 29)],
      [date(2023, 7, 2), Weekday::Thursday, date(2023, 6, 29)],
      [date(2023, 7, 1), Weekday::Thursday, date(2023, 6, 29)],
      [date(2023, 6, 30), Weekday::Thursday, date(2023, 6, 29)],
      [date(2023, 6, 29), Weekday::Thursday, date(2023, 6, 22)],
    ].each do |date, weekday, expected|
      assert_case expected, date.prev_occurrence(weekday)
    end
  end

  # <tt>date.rs:1263</tt>, +nth_next_occurrence_test+.
  def test_nth_next_occurrence_test
    [
      [date(2023, 6, 25), Weekday::Monday, 5, date(2023, 7, 24)],
      [date(2023, 6, 26), Weekday::Monday, 5, date(2023, 7, 31)],
    ].each do |date, weekday, n, expected|
      assert_case expected, date.nth_next_occurrence(weekday, n)
    end
  end

  # <tt>date.rs:1275</tt>, +nth_prev_occurrence_test+.
  def test_nth_prev_occurrence_test
    [
      [date(2023, 6, 27), Weekday::Monday, 3, date(2023, 6, 12)],
      [date(2023, 6, 26), Weekday::Monday, 3, date(2023, 6, 5)],
    ].each do |date, weekday, n, expected|
      assert_case expected, date.nth_prev_occurrence(weekday, n)
    end
  end

  # <tt>date.rs:1286</tt>, +next_occurrence_overflow_test+: Rust's panic is
  # RangeError here. Year +999999 needs large-dates, so the case moves to
  # the same week before Date::MAX, 9999-12-25.
  def test_next_occurrence_overflow_test
    assert_raises(RangeError) { date(9999, 12, 25).next_occurrence(Weekday::Saturday) }
  end

  # <tt>date.rs:1292</tt>, +prev_occurrence_overflow_test+, at -9999-01-07
  # for -999999-01-07.
  def test_prev_occurrence_overflow_test
    assert_raises(RangeError) { date(-9999, 1, 7).prev_occurrence(Weekday::Sunday) }
  end

  # <tt>date.rs:1298</tt>, +nth_next_occurrence_overflow_test+, at
  # 9999-12-25 for +999999-12-25.
  def test_nth_next_occurrence_overflow_test
    assert_raises(RangeError) { date(9999, 12, 25).nth_next_occurrence(Weekday::Saturday, 1) }
  end

  # <tt>date.rs:1304</tt>, +nth_next_occurence_zeroth_occurence_test+.
  def test_nth_next_occurence_zeroth_occurence_test
    assert_raises(RangeError) { date(2023, 6, 25).nth_next_occurrence(Weekday::Monday, 0) }
  end

  # <tt>date.rs:1310</tt>, +nth_prev_occurence_zeroth_occurence_test+.
  def test_nth_prev_occurence_zeroth_occurence_test
    assert_raises(RangeError) { date(2023, 6, 27).nth_prev_occurrence(Weekday::Monday, 0) }
  end

  # <tt>date.rs:1316</tt>, +nth_prev_occurrence_overflow_test+, at
  # -9999-01-07 for -999999-01-07.
  def test_nth_prev_occurrence_overflow_test
    assert_raises(RangeError) { date(-9999, 1, 7).nth_prev_occurrence(Weekday::Sunday, 1) }
  end
end

#--
# SPDX-SnippetEnd
#++
