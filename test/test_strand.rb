require 'helper'

class TestStrand < Test::Unit::TestCase

  test "em" do
    results = []

    s1 = Strand.new do
      results << "1a"
      Strand.sleep(0.1)
      results << "1b"
      Strand.sleep(0.1)
      results << "1c"
    end
    
    s2 = Strand.new do
      results << "2a"
      Strand.sleep(0.1)
      results << "2b"
      Strand.sleep(0.1)
      results << "2c"
    end

    s1.join
    s2.join

    assert_equal false, s1.alive?
    assert_equal false, s2.alive?
    assert_equal %w[1a 2a 1b 2b 1c 2c], results
  end

  test "yield" do
    results = []

    s1 = Strand.new do
      results << "1a"
      Strand.pass
      results << "1b"
      Strand.pass
      results << "1c"
    end
    
    s2 = Strand.new do
      results << "2a"
      Strand.pass
      results << "2b"
      Strand.pass
      results << "2c"
    end

    s1.join
    s2.join

    assert_equal false, s1.alive?
    assert_equal false, s2.alive?
    assert_equal %w[1a 2a 1b 2b 1c 2c], results
  end

  test "improper_yield" do
    test_fiber = Fiber.current
    strand = Strand.new do
      fiber = Fiber.current
      EM::Timer.new(0.01) do
        assert_raise(FiberError){ fiber.resume }
        test_fiber.resume
      end
      Strand.pass
    end

    assert strand.join
    Fiber.yield
  end

  test "improper_pass" do
    fiber = nil
    strand = Strand.new do
      fiber = Fiber.current
      Strand.pass
      Strand.yield
    end
    fiber.resume
  end

  test "strand_list" do
    Strand.new do
      Strand.new{ Strand.yield }
      assert Strand.list.inspect =~ /#<Strand:0x(.+) run>, #<Strand:0x(.+) yielded>/
    end
  end

  test "wait" do
    x = nil
    cond = Strand::ConditionVariable.new
    Strand.new{ cond.wait; x = 1; cond.signal }
    assert_nil x
    cond.signal
    cond.wait
    assert_equal 1, x
  end

  test "wait_timeout" do
    x = nil
    cond = Strand::ConditionVariable.new
    Strand.new{ cond.wait; x = 1; cond.signal }
    assert_nil x
    cond.wait(0.01)
    assert_nil x
  end

  test "signal" do
    result = []
    cond = Strand::ConditionVariable.new
    strand = Strand.new{ result << 1; cond.wait; result << 2 }
    result << 3
    cond.signal
    result << 4
    strand.join
    assert_equal [1, 3, 4, 2], result
  end

end
