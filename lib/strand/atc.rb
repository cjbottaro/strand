module Strand
  class Atc #:nodoc:
    
    def initialize(options = {})
      @timeout  = options[:timeout]
      @cond     = ConditionVariable.new
      @states   = []
    end

    # Wait for state to happen.
    def wait(state, timeout = nil)
      return true if @states.include?(state)
      timeout ||= @timeout
      if timeout
        wait_with_timeout(state, timeout)
      else
        wait_without_timeout(state)
      end
    end

    def signal(state)
      @states << state
      @cond.signal
    end

  private
    
    def wait_with_timeout(state, timeout)
      while not @states.include?(state)
        return @states.include?(state) if @cond.wait(timeout) == false
      end
      true
    end

    def wait_without_timeout(state)
      @cond.wait while not @states.include?(state)
      true
    end

  end
end
