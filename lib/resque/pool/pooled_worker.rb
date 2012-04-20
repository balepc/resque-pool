class Resque::Pool

  class PooledWorker < ::Resque::Worker

    def initialize(*args)
      @pool_master_pid = Process.pid
      super
    end

    def pool_master_has_gone_away?
      @pool_master_pid && @pool_master_pid != Process.ppid
    end

    # override +shutdown?+ method
    def shutdown?
      super || pool_master_has_gone_away?
    end


    # This is a hack, that makes resque-pool crazy!
    #
    #
    def work(interval = 5.0, &block)
      interval = Float(interval)
      $0 = "resque: Starting"
      startup

      loop do
        break if shutdown?

        if not paused? and job = reserve
          log "got: #{job.inspect}"
          job.worker = self
          run_hook :before_fork, job
          working_on job

          perform(job, &block)

          done_working
          @child = nil
        else
          break if interval.zero?
          log! "Sleeping for #{interval} seconds"
          procline paused? ? "Paused" : "Waiting for #{@queues.join(',')}"
          sleep interval
        end
      end

    ensure
      unregister_worker
    end


  end

end
