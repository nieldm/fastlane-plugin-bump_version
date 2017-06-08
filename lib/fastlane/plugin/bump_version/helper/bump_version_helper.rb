module Fastlane
  module Helper
    class BumpVersionHelper
      # class methods that you define here become available in your action
      # as `Helper::BumpVersionHelper.your_method`
      #
      def self.show_message
        UI.message("Hello from the bump_version plugin helper!")
      end
    end
  end
end
