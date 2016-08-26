require File.expand_path('../spec_helper', __FILE__)

# rubocop:disable Metrics/LineLength

TEST_MESSAGES = {
  subject_length: 'This is a really long subject line and should result in an error',
  subject_period: 'This subject line ends in a period.',
  empty_line: "This subject line is fine\nBut then I forgot the empty line separating the subject and the body.",
  all_errors: "This is a really long subject and it even ends in a period.\nNot to mention the missing empty line!",
  valid:  "This is a valid message\n\nYou can tell because it meets all the criteria and the linter does not complain."
}.freeze

# rubocop:enable Metrics/LineLength

def report_counts(status_report)
  status_report.values.flatten.count
end

# rubocop:disable Metrics/ClassLength

module Danger
  class DangerCommitLint
    describe 'DangerCommitLint' do
      it 'should be a plugin' do
        expect(Danger::DangerCommitLint.new(nil)).to be_a Danger::Plugin
      end
    end

    describe 'check' do
      before do
        @dangerfile = testing_dangerfile
        @commit_lint = @dangerfile.commit_lint
        allow(@dangerfile.git).to receive(:commits).and_return([commit])
      end

      let(:commit) { double(:commit, message: message) }

      context 'with a long subject line' do
        let(:message) { TEST_MESSAGES[:subject_length] }

        it 'adds an error for the subject_line check' do
          @commit_lint.check

          status_report = @commit_lint.status_report
          expect(report_counts(status_report)).to eq 1
          expect(status_report[:errors]).to eq [SubjectLengthCheck::MESSAGE]
        end
      end

      context 'with a period at the end of the subject line' do
        let(:message) { TEST_MESSAGES[:subject_period] }

        it 'adds an error for the subject_period check' do
          @commit_lint.check

          status_report = @commit_lint.status_report
          expect(report_counts(status_report)).to eq 1
          expect(status_report[:errors]).to eq [SubjectPeriodCheck::MESSAGE]
        end
      end

      context 'without an empty line between subject and body' do
        let(:message) { TEST_MESSAGES[:empty_line] }

        it 'adds an error for the empty_line check' do
          @commit_lint.check

          status_report = @commit_lint.status_report
          expect(report_counts(status_report)).to eq 1
          expect(status_report[:errors]).to eq [EmptyLineCheck::MESSAGE]
        end
      end

      context 'with a valid commit message' do
        let(:message) { TEST_MESSAGES[:valid] }

        it 'does nothing' do
          @commit_lint.check

          status_report = @commit_lint.status_report
          expect(report_counts(status_report)).to eq 0
        end
      end
    end

    describe 'disabling' do
      before do
        @dangerfile = testing_dangerfile
        @commit_lint = @dangerfile.commit_lint
        allow(@dangerfile.git).to receive(:commits).and_return([commit])
      end

      let(:commit) { double(:commit, message: message) }

      context 'skipping subject length check' do
        let(:message) { TEST_MESSAGES[:subject_length] }

        it 'does nothing' do
          @commit_lint.check disable: [:subject_length]

          status_report = @commit_lint.status_report
          expect(report_counts(status_report)).to eq 0
        end
      end

      context 'skipping subject period check' do
        let(:message) { TEST_MESSAGES[:subject_period] }

        it 'does nothing' do
          @commit_lint.check disable: [:subject_period]

          status_report = @commit_lint.status_report
          expect(report_counts(status_report)).to eq 0
        end
      end

      context 'skipping empty line check' do
        let(:message) { TEST_MESSAGES[:empty_line] }

        it 'does nothing' do
          @commit_lint.check disable: [:empty_line]

          status_report = @commit_lint.status_report
          expect(report_counts(status_report)).to eq 0
        end
      end

      context 'skipping all checks explicitly' do
        let(:message) { TEST_MESSAGES[:subject_length] }

        it 'warns that nothing was checked' do
          @commit_lint.check disable: :all

          status_report = @commit_lint.status_report
          expect(report_counts(status_report)).to eq 1
          expect(status_report[:warnings]).to eq [NOOP_MESSAGE]
        end
      end

      context 'skipping all checks implicitly' do
        let(:message) { TEST_MESSAGES[:subject_length] }

        it 'warns that nothing was checked' do
          all_checks = [:subject_length, :subject_period, :empty_line]
          @commit_lint.check disable: all_checks

          status_report = @commit_lint.status_report
          expect(report_counts(status_report)).to eq 1
          expect(status_report[:warnings]).to eq [NOOP_MESSAGE]
        end
      end
    end

    describe 'warn configuration' do
      context 'with individual checks' do
        context 'with invalid messages' do
          it 'warns instead of failing' do
            checks = {
              subject_length: SubjectLengthCheck::MESSAGE,
              subject_period: SubjectPeriodCheck::MESSAGE,
              empty_line: EmptyLineCheck::MESSAGE
            }

            for (check, warning) in checks
              commit_lint = testing_dangerfile.commit_lint
              commit = double(:commit, message: TEST_MESSAGES[check])
              allow(commit_lint.git).to receive(:commits).and_return([commit])

              commit_lint.check warn: [check]

              status_report = commit_lint.status_report
              expect(report_counts(status_report)).to eq 1
              expect(status_report[:warnings]).to eq [warning]
            end
          end
        end

        context 'with valid messages' do
          it 'does nothing' do
            checks = {
              subject_length: SubjectLengthCheck::MESSAGE,
              subject_period: SubjectPeriodCheck::MESSAGE,
              empty_line: EmptyLineCheck::MESSAGE
            }

            for (check, _) in checks
              commit_lint = testing_dangerfile.commit_lint
              commit = double(:commit, message: TEST_MESSAGES[:valid])
              allow(commit_lint.git).to receive(:commits).and_return([commit])

              commit_lint.check warn: [check]

              status_report = commit_lint.status_report
              expect(report_counts(status_report)).to eq 0
            end
          end
        end
      end

      context 'with all checks' do
        context 'with all errors' do
          it 'warns instead of failing' do
            commit_lint = testing_dangerfile.commit_lint
            commit = double(:commit, message: TEST_MESSAGES[:all_errors])
            allow(commit_lint.git).to receive(:commits).and_return([commit])

            commit_lint.check warn: :all

            status_report = commit_lint.status_report
            expect(report_counts(status_report)).to eq 3
            expect(status_report[:warnings]).to eq [
              SubjectLengthCheck::MESSAGE,
              SubjectPeriodCheck::MESSAGE,
              EmptyLineCheck::MESSAGE
            ]
          end
        end

        context 'with a valid message' do
          it 'does nothing' do
            commit_lint = testing_dangerfile.commit_lint
            commit = double(:commit, message: TEST_MESSAGES[:valid])
            allow(commit_lint.git).to receive(:commits).and_return([commit])

            commit_lint.check warn: :all

            status_report = commit_lint.status_report
            expect(report_counts(status_report)).to eq 0
          end
        end
      end
    end
  end
end

# rubocop:enable Metrics/ClassLength
