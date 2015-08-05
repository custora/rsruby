require 'test/unit'
require 'rsruby'

class TestUnderscoreTranslation < Test::Unit::TestCase
  def setup
    @r = RSRuby.instance
  end

  def test_underscore_translation
    assert(@r.underscore_translation)
    assert_raise RException do @r.send("seq_len", {"length.out" => 10}) end
    @r.underscore_translation = false
    assert_nothing_raised { @r.send("seq_len", {"length.out" => 10}) }
  end

end
