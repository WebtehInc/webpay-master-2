require 'tilt/erb'
require 'rqrcode'

class Mailer < Roda

  plugin :mailer
  plugin :render

  route do |r|
    from_email = MemoryCache.fetch_setting('email_from_address')[0]

    # signup confirmation email
    r.on 'signup' do
      puts '=> sending signup confirmation email ...'
      r.mail 'confirm' do |user|
        from from_email
        to user[:email]
        subject "[#{WebPay.opts[:app_name]}] - confirm your registration"

        # change size based on uri length
        otp_uri = ROTP::TOTP.new(user[:otp_code]).provisioning_uri("#{WebPay.opts[:app_name]}:#{user[:email]}")
        qr_size = 8
        qr_code = nil

        while qr_code == nil
          begin
            qr_code = RQRCode::QRCode.new(otp_uri, :size => qr_size, :level => :l)
          rescue RQRCode::QRCodeRunTimeError => e
            qr_size += 1
          end
        end

        # render template
        html_part render('signup/confirm', locals: {user: user, qr_code: qr_code})
      end
    end

    # password reset email
    r.on 'login' do
      r.mail 'reset_password' do |user|
        puts "=> sending email to #{user[:email]} for password reset ..."
        from from_email
        to user[:email]
        subject "[#{WebPay.opts[:app_name]}] - password reset request"
        html_part render('login/reset_password', locals: {user: user})
      end
    end

    r.on 'app' do
      r.mail 'exception' do |e, context, time_spent|
        puts '=> sending exception email ...'
        from from_email
        to Mailer.opts[:error_email]
        subject "ERROR: [#{WebPay.opts[:app_name]}] #{time_spent} sec - #{e.class}: #{e.message}"
        html_part render('app/exception', locals: {e: e, context: context})
      end

      r.mail 'voucher_low_stock' do |product|
        puts '=> sending voucher low stock emails to bank ...'
        from from_email
        to MemoryCache.fetch_setting('voucher_low_stock_alert_emails')
        subject "[#{WebPay.opts[:app_name]}] - low stock for #{product.name}: #{product.quantity} left"
        html_part render('app/voucher_low_stock', locals: {product: product})
      end
    end

    r.on 'merchant' do
      puts '=> sending voucher low stock email to merchant ...'
      r.mail 'voucher_low_stock' do |account, voucher_stock|
        from from_email
        to account.merchant_email
        subject "[#{WebPay.opts[:app_name]}] - low stock for #{voucher_stock.name}: #{voucher_stock.quantity - 1} left"
        html_part render('merchant/voucher_low_stock', locals: {account: account, voucher_stock: voucher_stock})
      end
    end

    r.on 'user' do
      puts '=> sending transaction notification to user ...'
      r.mail 'transaction' do |transaction, account, user|
        from from_email
        to user[:email]
        subject "[#{WebPay.opts[:app_name]}] - #{WALLET_TRANSACTION_TYPES[transaction.transaction_type.to_sym]} transaction notification"
        html_part render('user/transaction', locals: {transaction: transaction, account: account, user: user})
      end
    end

  end
end
