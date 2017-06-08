describe Fastlane::Actions::BumpVersionAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The bump_version plugin is working!")

      Fastlane::Actions::BumpVersionAction.run(nil)
    end
  end
end
