require "log"

module Discord
    abstract class DiscordPlugin
        getter commands : Set(String)
        getter name : String = "DiscordPlugin"
        getter passive : Bool = false

        def initialize(@commands, @name, @passive)
        end

        def execute(command, client, payload)
            Log.error { "command \"#{command}\" not implemented for plugin \"#{name}\"" }
        end

        def passive(client, payload)
            Log.error { "passive not implemented for plugin \"#{name}\"" }
        end
    end
end
