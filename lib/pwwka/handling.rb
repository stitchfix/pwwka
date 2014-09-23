require 'forwardable'
module Pwwka

  module Handling
    extend Forwardable

    def_delegators :'Pwwka::Transmitter', :send_message!, :send_message_safely

  end

end
