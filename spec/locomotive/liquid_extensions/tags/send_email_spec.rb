require 'spec_helper'

describe Locomotive::LiquidExtensions::Tags::SendEmail do

  let(:tag_class) { Locomotive::LiquidExtensions::Tags::SendEmail }

  describe '#display' do

    let(:tokens) { ['Hello ', '{{ send_email.to }}', '{% endsend_email %}', 'outside'] }
    let(:attachment) { '' }
    let(:options) { "to: 'john@doe.net', from: 'me@locomotivecms.com', subject: 'Hello world', html: false, smtp_address: 'smtp.example.com', smtp_user_name: 'user', smtp_password: 'password'#{attachment}" }
    let(:assigns) { {} }
    let(:context) { Liquid::Context.new({}, assigns, { logger: CustomLogger }) }

    subject { tag_class.new('send_email', options, tokens) }

    it 'sends the email over Pony' do
      Pony.expects(:mail).with(
        to:           'john@doe.net',
        from:         'me@locomotivecms.com',
        subject:      'Hello world',
        body:         'Hello john@doe.net',
        via:          :smtp,
        via_options:  {
          address:    'smtp.example.com',
          user_name:  'user',
          password:   'password'
        }
      )
      subject.render(context).should be == ''
    end

    context 'with an attachment' do

      context 'inline content' do

        let(:attachment) { ", attachment_name: 'foo.txt', attachment_value: 'Hello world'" }

        it 'sends the email over Pony' do
          Pony.expects(:mail).with(
            to:           'john@doe.net',
            from:         'me@locomotivecms.com',
            subject:      'Hello world',
            body:         'Hello john@doe.net',
            via:          :smtp,
            via_options:  {
              address:    'smtp.example.com',
              user_name:  'user',
              password:   'password'
            },
            attachment:   {
              'foo.txt' => 'Hello world'
            }
          )
          subject.render(context).should be == ''
        end

      end

      context 'remote content' do

        let(:assigns) { { 'host' => 'acme.org' } }
        let(:attachment) { ", attachment_name: 'foo.txt', attachment_value: '/somewhere/foo.txt'" }

        before do
          Net::HTTP.expects(:get).with(URI('http://acme.org/somewhere/foo.txt')).returns('Hello world [file]')
        end

        it 'sends the email over Pony' do
          Pony.expects(:mail).with(
            to:           'john@doe.net',
            from:         'me@locomotivecms.com',
            subject:      'Hello world',
            body:         'Hello john@doe.net',
            via:          :smtp,
            via_options:  {
              address:    'smtp.example.com',
              user_name:  'user',
              password:   'password'
            },
            attachment:   {
              'foo.txt' => 'Hello world [file]'
            }
          )
          subject.render(context).should be == ''
        end

      end

    end

    context 'in Wagon' do

      let(:assigns) { { 'wagon' => true } }

      it 'does not send the email' do
        Pony.expects(:mail).never
        subject.render(context).should be == ''
      end

      it 'logs the message' do
        CustomLogger.expects(:info)
        subject.render(context).should be == ''
      end

    end

    context 'using a page as the body of the email' do

      let(:options) { "to: 'john@doe.net', from: 'me@locomotivecms.com', subject: 'Hello world', page_handle: 'email_template', smtp_address: 'smtp.example.com', smtp_user_name: 'user', smtp_password: 'password'" }
      let(:page) { SimplePage.new("Hello {{ send_email.to }}, Lorem ipsum...")}

      it 'sends the email over Pony' do
        subject.expects(:fetch_page).returns(page)
        Pony.expects(:mail).with(
          to:         'john@doe.net',
          from:       'me@locomotivecms.com',
          subject:    'Hello world',
          html_body:  'Hello john@doe.net, Lorem ipsum...',
          via:      :smtp,
          via_options: {
            address:    'smtp.example.com',
            user_name:  'user',
            password:   'password'
          }
        )
        subject.render(context).should be == ''
      end

      it 'raises an error if the page does not exist' do
        subject.expects(:fetch_page).returns(nil)
        lambda { subject.render(context) }.should raise_exception(%{[send_email] No page found with "email_template" as handle.})
      end

    end

  end

end