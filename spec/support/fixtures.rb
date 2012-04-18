
class Channel < Strand::EM::Queue
    alias receive shift
end


module StrandSpecs

  class SubStrand < Strand::EM::Thread
    def initialize(*args)
      super { args.first << 1 }
    end
  end

  class Status
    attr_reader :strand, :inspect, :status
    def initialize(strand)
      @strand = strand
      @alive = strand.alive?
      @inspect = strand.inspect
      @status = strand.status
      @stop = strand.stop?
    end

    def alive?
      @alive
    end

    def stop?
      @stop
    end
  end

  # TODO: In the great Thread spec rewrite, abstract this
  class << self
    attr_accessor :state
  end

  def self.clear_state
    @state = nil
  end

  # GG Not really necessary, if a strand is executing by
  # definition all other strands are dead or sleeping
  def self.spin_until_sleeping(t)
    Strand.pass while t.status and t.status != "sleep"
  end

  def self.sleeping_strand
    Strand.new do
      begin
        Strand.sleep
      rescue Object => e
        ScratchPad.record e
      end
    end
  end

  #GG: Only the current strand can be running, so you can never
  # find a running strand from outside the strand
  def self.running_strand
    Strand.new do
     begin
        StrandSpecs.state = :running
        loop { Strand.pass }
        ScratchPad.record :woken
      rescue Object => e
        ScratchPad.record e
      end
    end
  end

  def self.completed_strand
    Strand.new {}
  end

  def self.status_of_current_strand
    Strand.new { Status.new(Strand.current) }.value
  end

  #GG: can't check a running strand from outside the strand
  def self.status_of_running_strand
    t = running_strand
    Strand.pass while t.status and t.status != "run"
    status = Status.new t
    t.kill
    t.join
    status
  end

  def self.status_of_completed_strand
    t = completed_strand
    t.join
    Status.new t
  end

  def self.status_of_sleeping_strand
    t = sleeping_strand
    Strand.pass while t.status and t.status != 'sleep'
    status = Status.new t
    t.run
    t.join
    status
  end

  def self.status_of_blocked_strand
    m = Strand::Mutex.new
    m.lock
    t = Strand.new { m.lock }
    status = Status.new t
    m.unlock
    t.join
    status
  end

  def self.status_of_aborting_strand
  end

  def self.status_of_killed_strand
    t = Strand.new { Strand.sleep }
    t.kill
    t.join
    Status.new t
  end

  def self.status_of_strand_with_uncaught_exception
    t = Strand.new { raise "error" }
    begin
      t.join
    rescue RuntimeError
    end
    Status.new t
  end

  def self.status_of_dying_running_strand
    status = nil
    t = dying_strand_ensures { status = Status.new Strand.current }
    t.join
    status
  end

  def self.status_of_dying_sleeping_strand
    t = dying_strand_ensures { Strand.stop; }
    status = Status.new t
    t.wakeup
    t.join
    status
  end

  def self.dying_strand_ensures(kill_method_name=:kill)
    t = Strand.new do
      begin
        Strand.current.send(kill_method_name)
      ensure
        yield
      end
    end
  end

  def self.dying_strand_with_outer_ensure(kill_method_name=:kill)
    t = Strand.new do
      begin
        begin
          Strand.current.send(kill_method_name)
        ensure
          raise "In dying strand"
        end
      ensure
        yield
      end
    end
  end

  def self.join_dying_strand_with_outer_ensure(kill_method_name=:kill)
    t = dying_strand_with_outer_ensure(kill_method_name) { yield }
    lambda { t.join }.should raise_error(RuntimeError, "In dying strand")
    return t
  end

  def self.wakeup_dying_sleeping_strand(kill_method_name=:kill)
    t = StrandSpecs.dying_strand_ensures(kill_method_name) { yield }
    t.wakeup
    t.join
  end

  def self.critical_is_reset
    # Create another strand to verify that it can call Strand.critical=
    t = Strand.new do
      initial_critical = Strand.critical
      Strand.critical = true
      Strand.critical = false
      initial_critical == false && Strand.critical == false
    end
    v = t.value
    t.join
    v
  end

  def self.counter
    @@counter
  end

  def self.counter= c
    @@counter = c
  end

  def self.increment_counter(incr)
    incr.times do
      begin
        Strand.critical = true
        @@counter += 1
      ensure
        Strand.critical = false
      end
    end
  end

  def self.critical_strand1()
    Strand.critical = true
    Strand.current.key?(:strand_specs).should == false
  end

  def self.critical_strand2(isStrandStop)
    Strand.current[:strand_specs].should == 101
    Strand.critical.should == !isStrandStop
    if not isStrandStop
      Strand.critical = false
    end
  end

  def self.main_strand1(critical_strand, isStrandSleep, isStrandStop)
    # Strand.stop resets Strand.critical. Also, with native strands, the Strand.Stop may not have executed yet
    # since the main strand will race with the critical strand
    if not isStrandStop
      Strand.critical.should == true
    end
    critical_strand[:strand_specs] = 101
    if isStrandSleep or isStrandStop
      # Strand#wakeup calls are not queued up. So we need to ensure that the strand is sleeping before calling wakeup
      Strand.pass while critical_strand.status and critical_strand.status != "sleep"
      critical_strand.wakeup
    end
  end

  def self.main_strand2(critical_strand)
    Strand.pass # The join below seems to cause a deadlock with CRuby unless Strand.pass is called first
    critical_strand.join
    Strand.critical.should == false
  end

  def self.critical_strand_yields_to_main_strand(isStrandSleep=false, isStrandStop=false)
    @@after_first_sleep = false

    critical_strand = Strand.new do
      Strand.pass while Strand.main.status and Strand.main.status != "sleep"
      critical_strand1()
      Strand.main.wakeup
      yield
      Strand.pass while @@after_first_sleep != true # Need to ensure that the next statement does not see the first sleep itself
      Strand.pass while Strand.main.status and Strand.main.status != "sleep"
      critical_strand2(isStrandStop)
      Strand.main.wakeup
    end

    sleep 5
    @@after_first_sleep = true
    main_strand1(critical_strand, isStrandSleep, isStrandStop)
    sleep 5
    main_strand2(critical_strand)
  end

  def self.create_critical_strand()
    critical_strand = Strand.new do
      Strand.critical = true
      yield
      Strand.critical = false
    end
    return critical_strand
  end

  def self.create_and_kill_critical_strand(passAfterKill=false)
    critical_strand = StrandSpecs.create_critical_strand do
      Strand.current.kill
      if passAfterKill
        Strand.pass
      end
      ScratchPad.record("status=" + Strand.current.status)
    end
  end
end
