# Migration: Update ANG to XCG currency code
# Central Bank of Curacao compliance: Caribbean Guilder (XCG) goes live March 31st, 2025
# This migration updates all currency references from ANG (Antillean Guilder) to XCG (Caribbean Guilder)
#
# Affected tables:
# - accounts (13 rows in dev)
# - transactions (5,241 rows in dev)
# - fees (15 rows in dev)
# - limits (8 rows in dev)
# - products (12 rows in dev)
# - operators (23 rows in dev)
#
# Total: 5,312 rows updated in development database
#
# Run with: bundle exec rake db:migrate
# Rollback with: bundle exec rake db:rollback

Sequel.migration do
  up do
    puts "Starting ANG → XCG currency migration..."

    # Update accounts
    count = from(:accounts).where(currency: 'ANG').update(currency: 'XCG')
    puts "  ✓ Updated #{count} accounts"

    # Update transactions
    count = from(:transactions).where(currency: 'ANG').update(currency: 'XCG')
    puts "  ✓ Updated #{count} transactions"

    # Update fees
    count = from(:fees).where(currency: 'ANG').update(currency: 'XCG')
    puts "  ✓ Updated #{count} fees"

    # Update limits
    count = from(:limits).where(currency: 'ANG').update(currency: 'XCG')
    puts "  ✓ Updated #{count} limits"

    # Update products
    count = from(:products).where(currency: 'ANG').update(currency: 'XCG')
    puts "  ✓ Updated #{count} products"

    # Update operators
    count = from(:operators).where(currency: 'ANG').update(currency: 'XCG')
    puts "  ✓ Updated #{count} operators"

    puts "ANG → XCG migration completed successfully!"
  end

  down do
    puts "Rolling back XCG → ANG..."

    # Rollback accounts
    count = from(:accounts).where(currency: 'XCG').update(currency: 'ANG')
    puts "  ✓ Rolled back #{count} accounts"

    # Rollback transactions
    count = from(:transactions).where(currency: 'XCG').update(currency: 'ANG')
    puts "  ✓ Rolled back #{count} transactions"

    # Rollback fees
    count = from(:fees).where(currency: 'XCG').update(currency: 'ANG')
    puts "  ✓ Rolled back #{count} fees"

    # Rollback limits
    count = from(:limits).where(currency: 'XCG').update(currency: 'ANG')
    puts "  ✓ Rolled back #{count} limits"

    # Rollback products
    count = from(:products).where(currency: 'XCG').update(currency: 'ANG')
    puts "  ✓ Rolled back #{count} products"

    # Rollback operators
    count = from(:operators).where(currency: 'XCG').update(currency: 'ANG')
    puts "  ✓ Rolled back #{count} operators"

    puts "Rollback completed!"
  end
end
