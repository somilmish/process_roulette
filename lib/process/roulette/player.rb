require 'socket'
require 'process/roulette/enhance_socket'

require 'sys/proctable'

module Process
  module Roulette

    # Encapsulates the player entity, participating in the roulette game by
    # killing random processes in coordination with the croupier server.
    class Player
      def initialize(host, port, username)
        @host = host
        @port = port
        @username = username
      end

      def play
        puts 'connecting...'
        socket = Process::Roulette::EnhanceSocket(TCPSocket.new(@host, @port))

        _handshake(socket)
        _play_loop(socket)

        puts 'finishing...'
        socket.close
      end

      def _handshake(socket)
        socket.send_packet("OK:#{@username}")

        packet = socket.wait_with_ping
        abort 'lost connection' unless packet

        return if packet == 'OK'

        socket.close
        abort 'username already taken!'
      end

      def _play_loop(socket)
        loop do
          packet = socket.wait_with_ping
          abort 'lost connection' unless packet

          break if _handle_packet(socket, packet)
        end
      end

      def _handle_packet(socket, packet)
        if packet == 'GO'
          _pull_trigger(socket)

          puts 'survived!'
          socket.send_packet('OK')
        else
          puts "unexpected packet: #{packet.inspect}"
        end

        false
      end

      def _pull_trigger(socket)
        processes = ::Sys::ProcTable.ps
        victim = processes.sample

        # alternatively: write to random memory locations?
        socket.send_packet(victim.comm)

        puts "pulling the trigger on \##{victim.pid} (#{victim.comm})"
        Process.kill('KILL', victim.pid)

        # give some time to make sure the kill has its effect
        sleep 0.1
      end
    end

  end
end
