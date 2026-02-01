-- Create stocks configuration table
CREATE TABLE IF NOT EXISTS stocks_config (
    symbol VARCHAR(10) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    base_price DECIMAL(10,2) NOT NULL,
    volatility DECIMAL(5,4) NOT NULL,
    liquidity_factor DECIMAL(3,2) NOT NULL,
    logo_url TEXT,
    enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create stocks history table
CREATE TABLE IF NOT EXISTS stocks_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    symbol VARCHAR(10),
    price DECIMAL(10,2),
    reason TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (symbol) REFERENCES stocks_config(symbol)
);

-- Create player stocks table
CREATE TABLE IF NOT EXISTS player_stocks (
    citizenid VARCHAR(50),
    symbol VARCHAR(10),
    amount INT,
    average_price DECIMAL(10,2),
    PRIMARY KEY (citizenid, symbol),
    FOREIGN KEY (symbol) REFERENCES stocks_config(symbol)
);

-- Create stock transactions table
CREATE TABLE IF NOT EXISTS stock_transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(50),
    type ENUM('BUY', 'SELL'),
    symbol VARCHAR(10),
    amount INT,
    price_per_share DECIMAL(10,2),
    total_value DECIMAL(10,2),
    profit_loss DECIMAL(10,2),
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_citizenid (citizenid),
    INDEX idx_timestamp (timestamp),
    FOREIGN KEY (symbol) REFERENCES stocks_config(symbol)
);

-- Insert default stocks
INSERT INTO stocks_config (symbol, name, base_price, volatility, liquidity_factor, logo_url) VALUES
('LIFE', 'Life Invader', 180.00, 0.0045, 1.00, 'https://static.wikia.nocookie.net/gtawiki/images/b/b6/Lifeinvader-GTAV-Logo.png'),
('MAZE', 'Maze Bank', 250.00, 0.0078, 0.80, NULL),
('BLST', 'Bleeter Corporation', 330.00, 0.0023, 0.90, NULL),
('PGIS', 'Pegasus Lifestyle', 140.00, 0.0056, 1.00, NULL),
('WZEL', 'Weazel News Corp', 145.00, 0.0034, 0.90, NULL),
('MORS', 'Mors Mutual Insurance', 320.00, 0.0067, 0.85, NULL),
('MERW', 'Merryweather Security', 480.00, 0.0089, 0.80, NULL),
('FLCA', 'Fleeca Banking Group', 155.00, 0.0012, 1.10, 'https://static.wikia.nocookie.net/gtawiki/images/b/bd/Fleeca-GTAV-Logo.png');
  


-- REQUIRED TABLES (idempotent)
CREATE TABLE IF NOT EXISTS exchange_portfolio (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  symbol VARCHAR(10) NOT NULL,
  quantity INT NOT NULL DEFAULT 0,
  avg_price DECIMAL(10,2) NOT NULL DEFAULT 0,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_user (user_id), INDEX idx_symbol (symbol)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS exchange_deposits (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  amount DECIMAL(12,2) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user (user_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS exchange_withdraws (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  amount DECIMAL(12,2) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user (user_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS exchange_withdraw_requests (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  amount DECIMAL(12,2) NOT NULL,
  status ENUM('pending','approved','rejected') DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user (user_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS exchange_tickets (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  subject VARCHAR(200) NOT NULL,
  message TEXT NOT NULL,
  status ENUM('open','closed') DEFAULT 'open',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user (user_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS exchange_events (
  id INT AUTO_INCREMENT PRIMARY KEY,
  kind VARCHAR(32) NOT NULL,
  title VARCHAR(200) NOT NULL,
  details TEXT,
  amount DECIMAL(12,2),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS exchange_subscriptions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  citizenid VARCHAR(64) NOT NULL UNIQUE,
  active_until DATETIME
) ENGINE=InnoDB;




-- REQUIRED TABLES (idempotent)
CREATE TABLE IF NOT EXISTS exchange_portfolio (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  symbol VARCHAR(10) NOT NULL,
  quantity INT NOT NULL DEFAULT 0,
  avg_price DECIMAL(10,2) NOT NULL DEFAULT 0,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_user (user_id), INDEX idx_symbol (symbol)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS exchange_deposits (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  amount DECIMAL(12,2) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user (user_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS exchange_withdraws (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  amount DECIMAL(12,2) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user (user_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS exchange_withdraw_requests (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  amount DECIMAL(12,2) NOT NULL,
  status ENUM('pending','approved','rejected') DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user (user_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS exchange_tickets (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  subject VARCHAR(200) NOT NULL,
  message TEXT NOT NULL,
  status ENUM('open','closed') DEFAULT 'open',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user (user_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS exchange_events (
  id INT AUTO_INCREMENT PRIMARY KEY,
  kind VARCHAR(32) NOT NULL,
  title VARCHAR(200) NOT NULL,
  details TEXT,
  amount DECIMAL(12,2),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS exchange_subscriptions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  citizenid VARCHAR(64) NOT NULL UNIQUE,
  active_until DATETIME
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS exchange_chat (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  message TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user (user_id)
) ENGINE=InnoDB;

