require "roda"
require "sequel"

# faster JSON
require "oj"
Oj.mimic_JSON

# load env settings from file
puts "* Loading env from .dotenv file"
require "dotenv"
Dotenv.load

# Ruby 3.x compatibility fix for ancient dry-* gems
require "./ruby3_compat"

require "./utils"
require "./mailer"
require "./env/environment"
require "./models"

# move to gem
require "./plugins/jwt"

class WebPay < Roda
  plugin :json
  plugin :json_parser
  plugin :symbolized_params
  plugin :placeholder_string_matchers # placeholder symbol matchers are deprecated by default and will be removed in Roda 3
  plugin :pass

  # load routes folder
  plugin :multi_route
  Dir["./routes/*.rb", "./routes/public/*.rb", "./routes/private/*.rb"].each { |f| require f }

  # load env settings
  plugin :environments
  include Environment

  # include custom request/response methods
  plugin :module_include
  request_module do

    # login user and render jwt
    def finalize_login(user, context)
      User.update_login_data(user[:id], old_data = user.values, self)
      LoginTrail.insert(user[:id], self)
      context.send_token!(user[:id], { user: user.public_values, spa_file_name: $SPA_FILE_NAME })
    end

    # return paginated dataset
    def paginated_dataset(per_page, count, dataset)
      response.headers["X-per-page"] = per_page
      response.headers["X-total-count"] = count
      dataset
    end
  end

  # hooks
  plugin :hooks
  after do |res| # instrument request
    puts("Time: #{Time.now - @start_time} sec")
  end

  # error handler
  plugin :error_handler
  error do |error|
    Utils.error_handler(error, self)
    { error: error.class, message: error.message }
  end

  # start routing
  route do |r|
    response["Content-Type"] = "application/json"

    @start_time = Time.now
    # puts "#{@start_time}: #{r.request_method} #{r.path}" # we have similar line from puma
    puts "Params: #{params.mask_sensitive_attrs}" unless params.empty?

    # public
    r.root do
      # returns index.html
      ["It works!"]
    end

    r.on "api" do
      r.post "login" do
        puts "=> logging in ..."
        user = Login.call(self)
        r.finalize_login(user, self) if user
      end

      r.post "signup" do
        puts "=> signin up ..."
        Signup.call(self)
      end

      # for cache on client
      r.get "constants" do
        { pages: DB[:pages].select(:title, :body, :slug, :updated_at).all,
          operators: DB[:operators].select(:name, :code, :type).order(:name).all,
          products: DB[:products].select(:id, :name, :operator_code, :type).order(:name).all, # for lodgments template
          fees: DB[:fees].select(:account_type, :user_type, :transaction_type, :amount, :currency).where(active: true).all,
          constants: CONSTANTS_FOR_SPA }
      end

      r.get "info" do
        APP_ENV
      end

      r.on "activate-user/:token" do |token|
        r.get do
          User.find_values_by_attrs([:email, :first_name, :last_name], activation_token: token).try(:to_hash)
        end
        r.post do
          puts "=> activating user ..."
          user = ActivateUser.call(self)
          if user
            puts "=> generating account ..."
            Account.insert(user[:id], self)
            r.finalize_login(user, self)
          end
        end
      end

      r.on "reset-password" do
        puts "=> resetting password ..."

        r.on ":token" do |token|
          puts "=> getting user by reset password token ..."
          user = User.find_all_values_by_attrs(reset_password_token: token)

          r.get do
            user.try(:public_values)
          end

          r.post do
            puts "=> token ok, updating password ..."
            r.finalize_login(user, self) if ResetPassword.call(user[:id], self)
          end
        end

        # check email and generate reset token
        r.post do
          puts "=> getting user by email ..."
          user = User.find_values_by_attrs([:id, :email, :first_name, :last_name, :active], email: params[:email]).try(:to_hash)
          if user
            render_forbidden("cannot reset password for inactive user") unless user[:active]
            puts "=> generating reset password token ..."
            token = Utils.generate_random_token
            User.update_without_audit(user[:id], reset_password_token: token)
            user[:token] = token
            Mailer.sendmail("/login/reset_password", user)
            render_success(message: "password reset done")
          else
            puts "=> no user with given email ..."
            render_success # do not reveal non existent email to client
          end
        end
      end

      # MPOS routes below
      r.post ":api_route/retry" do |api_route|
        puts "=> MPOS: retrying #{api_route} ..."
        mapper = { "bill-payment" => BillPayment, "sell-voucher" => SellVoucher, "sell-prepaid" => SellPrepaid, "top-up" => TopUp, "sale-wallet" => SaleWallet }
        RetryTransaction.call(mapper[api_route], self)
      end

      r.post "configure-terminal" do
        puts "=> MPOS: configuring terminal ..."
        ConfigureTerminal.call(self)
      end

      r.post "authorize" do
        puts "=> MPOS: authorizing ..."
        Authorize.call(self)
      end

      r.post "top-up" do
        puts "=> MPOS: topping-up ..."
        TopUp.call(self)
      end

      r.post "reverse-top-up" do
        puts "=> MPOS: reversing top-up..."
        ReverseTopUp.call(self)
      end

      r.post "sale-wallet" do
        puts "=> MPOS: sale wallet ..."
        SaleWallet.call(self)
      end

      r.post "sell-voucher" do
        puts "=> MPOS: seling voucher ..."
        SellVoucher.call(self)
      end

      r.post "sell-prepaid" do
        puts "=> MPOS: seling prepaid voucher ..."
        SellPrepaid.call(self)
      end

      r.post "bill-payment" do
        puts "=> MPOS: paying a bill ..."
        BillPayment.call(self)
      end

      r.post "reverse-bill-payment" do
        puts "=> MPOS: reversing bill payment..."
        ReverseBillPayment.call(self)
      end

      r.post "bill-balance-inquiry" do
        puts "=> MPOS: bill balance inquiry ..."
        BillBalanceInquiry.call(self)
      end

      r.post "close-services-batch" do
        puts "=> MPOS: closing services batch ..."
        CloseServicesBatch.call(self)
      end

      r.post "create-cashier" do
        puts "=> MPOS: creating cashier ..."
        ApiCreateCashier.call(self)
      end

      r.post "update-cashier" do
        puts "=> MPOS: updating cashier ..."
        ApiUpdateCashier.call(self)
      end

      r.post "change-cashier-pin" do
        puts "=> MPOS: changing cashier pin ..."
        ApiChangeCashierPin.call(self)
      end

      r.post "check-cashier-pin" do
        puts "=> MPOS: checking cashier pin ..."
        CheckCashierPin.call(self)
      end

      r.post "generate-csk" do
        puts "=> MPOS: generating csk ..."
        GenerateCSK.call(self)
      end

      r.post "download" do
        puts "=> MPOS: downloading file ..."
        ApiDownloadFile.call(self)
      end

      r.post "reverse-on-timeout" do
        puts "=> MPOS: saving tehnical reversal ..."
        ApiReverseOnTimeout.call(self)
      end

      r.on "services" do
        r.on "curgas" do
          r.post "check-order" do
            puts "=> MPOS: checking order for curgas ..."
            CurgasServiceHandler::CheckOrder.call(self)
          end

          r.on "new-order" do
            r.post "retry" do
              puts "=> MPOS: retrying recharge for pagatinu V2 ..."
              RetryTransaction.call(CurgasServiceHandler::NewOrder, self)
            end

            r.post do
              puts "=> MPOS: new order for curgas ..."
              CurgasServiceHandler::NewOrder.call(self)
            end
          end
        end

        r.on "pagatinu" do
          r.on "recharge" do
            r.post "retry" do
              puts "=> MPOS: retrying recharge for pagatinu V2 ..."
              RetryTransaction.call(PagatinuServiceHandler, self)
            end

            r.post do
              puts "=> MPOS: calling recharge for pagatinu V2 ..."
              PagatinuServiceHandler.call(self)
            end
          end
        end

        r.on "pagatinu-rest" do
          r.on "trial" do
            r.post do
              puts "=> MPOS: calling trial for pagatinu rest ..."
              PagatinuRestServiceHandler::Trial.call(self)
            end
          end

          r.on "credit" do
            r.post "retry" do
              puts "=> MPOS: retrying credit for pagatinu rest ..."
              RetryTransaction.call(PagatinuRestServiceHandler::Credit, self)
            end

            r.post do
              puts "=> MPOS: calling credit for pagatinu rest ..."
              PagatinuRestServiceHandler::Credit.call(self)
            end
          end
        end

        r.on "tax" do
          r.post "confirm-reference" do
            puts "=> MPOS: confirming reference for tax ..."
            TaxServiceHandler::ConfirmReference.call(self)
          end

          r.on "payment" do
            r.post "retry" do
              puts "=> MPOS: retrying payment for tax ..."
              RetryTransaction.call(TaxServiceHandler::Payment, self)
            end

            r.post do
              puts "=> MPOS: payment for tax ..."
              TaxServiceHandler::Payment.call(self)
            end
          end
        end
      end
    end

    # private routes started - 401
    # user must log in to continue
    authenticate!

    # select voucher to buy
    r.get "vouchers/:operator_code" do |code|
      Voucher.select(:name, :price).where(operator_code: code, status: "available").distinct(:name).all
    end

    # find account for transfer
    r.post "find-accounts/:attr" do |attr|
      puts "searching for account in transfer ..."
      if attr == "account_number"
        Account.where(account_number: params[:search][:account_number]).to_json(
          only: Account::PUBLIC_ATTRS,
          include: { users: { only: [:first_name, :last_name, :email, :phone] } },
        )
      else
        if params[:search] && user = User.where(params[:search]).first
          user.accounts_dataset.to_json(
            only: Account::PUBLIC_ATTRS,
            include: { users: { only: [:first_name, :last_name, :email, :phone] } },
          )
        end
      end
    end

    r.multi_route
  end
end

# config options for crypto
WebPayOpts = WebPay.opts
