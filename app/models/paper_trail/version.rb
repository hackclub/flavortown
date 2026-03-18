module PaperTrail
  class Version < ActiveRecord::Base
    include PaperTrail::VersionConcern

    before_update { raise ActiveRecord::ReadOnlyRecord, "Audit log versions are immutable" }
    before_destroy { raise ActiveRecord::ReadOnlyRecord, "Audit log versions are immutable" }
  end
end
