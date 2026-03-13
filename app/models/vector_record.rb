require "sqlite_vec"

class VectorRecord < ActiveRecord::Base
  self.abstract_class = true

  connects_to database: { writing: :vector, reading: :vector }

  def self.connection
    super.tap do |conn|
      raw = conn.raw_connection
      unless raw.instance_variable_get(:@sqlite_vec_loaded)
        raw.enable_load_extension(true)
        SqliteVec.load(raw)
        raw.enable_load_extension(false)
        raw.execute("PRAGMA journal_mode=WAL")
        raw.execute("PRAGMA synchronous=NORMAL")
        raw.instance_variable_set(:@sqlite_vec_loaded, true)
      end
    end
  end
end
