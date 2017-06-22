require 'credentials_manager'

module Fastlane
  module Actions
    module SharedValues
      BUMP_VERSION_LATEST_BUILD_NUMBER = :BUMP_VERSION_LATEST_BUILD_NUMBER
      BUMP_VERSION_BUILD_NUMBER = :BUMP_VERSION_BUILD_NUMBER
    end

    class BumpVersionAction < Action
      def self.run(params)
        require 'shellwords'
        require 'spaceship'
        UI.message("The bump_version plugin is working!")

        UI.message("Login to iTunes Connect (#{params[:username]})")
        Spaceship::Tunes.login(params[:username])
        Spaceship::Tunes.select_team
        UI.message("Login successful")

        app = Spaceship::Tunes::Application.find(params[:app_identifier])
        if params[:live]
          UI.message("Fetching the latest build number for live-version")
          build_nr = app.live_version.current_build_number
        else
          version_number = params[:version]
          unless version_number
            # Automatically fetch the latest version in testflight
            begin
              testflight_version = app.build_trains.keys.last
            rescue
              testflight_version = params[:version]
            end

            if testflight_version
              version_number = testflight_version
            else
              version_number = UI.input("You have to specify a new version number")
            end

          end

          UI.message("Fetching the latest build number for version #{version_number}")

          begin
            train = app.build_trains[version_number]
            sorted = train.builds.map(&:build_version).sort.sort do |a,b|
              a_split = a.split(".")
              b_split = b.split(".")
              case
              when a_split[0].to_i < b_split[0].to_i
                -1
              when a_split[0].to_i < b_split[0].to_i
                -1
              when a_split[0].to_i < b_split[0].to_i
                -1
              when a_split[0].to_i > b_split[0].to_i
                1
              when a_split[0].to_i > b_split[0].to_i
                1
              when a_split[0].to_i > b_split[0].to_i
                1
              when a_split[1].to_i < b_split[1].to_i
                -1
              when a_split[1].to_i < b_split[1].to_i
                -1
              when a_split[1].to_i < b_split[1].to_i
                -1
              when a_split[1].to_i > b_split[1].to_i
                1
              when a_split[1].to_i > b_split[1].to_i
                1
              when a_split[1].to_i > b_split[1].to_i
                1
              else
                a_split[2].to_i <=> b_split[2].to_i
              end
            end
            build_nr = sorted.last
          rescue
            UI.user_error!("could not find a build on iTC - and 'initial_build_number' option is not set") unless params[:initial_build_number]
            build_nr = params[:initial_build_number]
          end
        end
        UI.message("Latest upload is build number: #{build_nr}")
        Actions.lane_context[SharedValues::BUMP_VERSION_LATEST_BUILD_NUMBER] = build_nr

        version_parts = build_nr.split(".")
        if version_parts.length <= 1
          IncrementBuildNumberAction.run(params)
        else
          last_part = version_parts.last.to_i + 1
          version_parts.pop
          version_parts << last_part.to_s
          result_version = version_parts.join(".")
          UI.message("New build number is: #{result_version}")
          Actions.lane_context[SharedValues::BUMP_VERSION_BUILD_NUMBER] = result_version

          folder = params[:xcodeproj] ? File.join(params[:xcodeproj], '..') : '.'

          command_prefix = [
            'cd',
            File.expand_path(folder).shellescape,
            '&&'
          ].join(' ')

          command_suffix = [
            '&&',
            'cd',
            '-'
          ].join(' ')

          command = [
            command_prefix,
            'agvtool',
            params[:build_number] ? "new-version -all #{params[:build_number].to_s.strip}" : "new-version -all #{result_version}",
            command_suffix
          ].join(' ')

          if Helper.test?
            return Actions.lane_context[SharedValues::BUMP_VERSION_BUILD_NUMBER] = command
          else
            Actions.sh command

            # Store the new number in the shared hash
            build_number = `#{command_prefix} agvtool what-version`.split("\n").last.strip

            return Actions.lane_context[SharedValues::BUMP_VERSION_BUILD_NUMBER] = build_number
          end
        end
                
      end

      def self.description
        "Bump the iOS version with 0.0.0 format"
      end

      def self.authors
        ["Daniel Mendez"]
      end

      def self.return_value
        "Returns the new version"
      end

      def self.details
        "WIP"
      end

      def self.available_options
        user = CredentialsManager::AppfileConfig.try_fetch_value(:itunes_connect_id)
        user ||= CredentialsManager::AppfileConfig.try_fetch_value(:apple_id)

        [
          FastlaneCore::ConfigItem.new(key: :live,
                                       short_option: "-l",
                                       env_name: "CURRENT_BUILD_NUMBER_LIVE",
                                       description: "Query the live version (ready-for-sale)",
                                       optional: true,
                                       is_string: false,
                                       default_value: false),
          FastlaneCore::ConfigItem.new(key: :app_identifier,
                                       short_option: "-a",
                                       env_name: "FASTLANE_APP_IDENTIFIER",
                                       description: "The bundle identifier of your app",
                                       default_value: CredentialsManager::AppfileConfig.try_fetch_value(:app_identifier)),
          FastlaneCore::ConfigItem.new(key: :username,
                                       short_option: "-u",
                                       env_name: "ITUNESCONNECT_USER",
                                       description: "Your Apple ID Username",
                                       default_value: user),
          FastlaneCore::ConfigItem.new(key: :version,
                                       env_name: "LATEST_VERSION",
                                       description: "The version number whose latest build number we want",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :initial_build_number,
                                       env_name: "INITIAL_BUILD_NUMBER",
                                       description: "sets the build number to given value if no build is in current train",
                                       default_value: 1,
                                       is_string: false),
          FastlaneCore::ConfigItem.new(key: :team_id,
                                       short_option: "-k",
                                       env_name: "LATEST_TESTFLIGHT_BUILD_NUMBER_TEAM_ID",
                                       description: "The ID of your iTunes Connect team if you're in multiple teams",
                                       optional: true,
                                       is_string: false, # as we also allow integers, which we convert to strings anyway
                                       default_value: CredentialsManager::AppfileConfig.try_fetch_value(:itc_team_id),
                                       verify_block: proc do |value|
                                         ENV["FASTLANE_ITC_TEAM_ID"] = value.to_s
                                       end),
          FastlaneCore::ConfigItem.new(key: :team_name,
                                       short_option: "-e",
                                       env_name: "LATEST_TESTFLIGHT_BUILD_NUMBER_TEAM_NAME",
                                       description: "The name of your iTunes Connect team if you're in multiple teams",
                                       optional: true,
                                       default_value: CredentialsManager::AppfileConfig.try_fetch_value(:itc_team_name),
                                       verify_block: proc do |value|
                                         ENV["FASTLANE_ITC_TEAM_NAME"] = value.to_s
                                       end),
          FastlaneCore::ConfigItem.new(key: :build_number,
                                       env_name: "FL_BUILD_NUMBER_BUILD_NUMBER",
                                       description: "Change to a specific version",
                                       optional: true,
                                       is_string: false),
          FastlaneCore::ConfigItem.new(key: :xcodeproj,
                                       env_name: "FL_BUILD_NUMBER_PROJECT",
                                       description: "optional, you must specify the path to your main Xcode project if it is not in the project root directory",
                                       optional: true,
                                       verify_block: proc do |value|
                                         UI.user_error!("Please pass the path to the project, not the workspace") if value.end_with? ".xcworkspace"
                                         UI.user_error!("Could not find Xcode project") if !File.exist?(value) and !Helper.is_test?
                                       end)
        ]
      end

      def self.is_supported?(platform)
        [:ios, :mac].include?(platform)
        true
      end
    end
  end
end
