module SuperExport
  class Importer
    include SharedMethods
    
    def self.import
      models = [User] + (SuperExport.models - [User])
      models.each do |model|
        Importer.new(model).import
      end
    end
    
    attr_reader :model
    
    def initialize(model)
      @model = model
      @model.record_timestamps = false
    end
    
    def import
      files = Dir["#{model_export_root}/*.yml"]
      puts "Importing #{model} (#{files.size} found)"
      
      files.each do |file|
        record = YAML.load_file(file)
        
        created_by_id = record.respond_to?(:created_by) && record.created_by_id
        updated_by_id = record.respond_to?(:updated_by) && record.updated_by_id
        
        capture_user(record) do
          record.instance_variable_set(:@new_record, true)
          record.save(false)
          if created_by_id || updated_by_id
            updates = {}
            updates[:created_by_id] = created_by_id if created_by_id
            updates[:updated_by_id] = updated_by_id if updated_by_id
            model.update_all(updates, ['id = ?', record.id])
          end
        end
      end
    end
    
    def capture_user(record, &block)
      if User === record
        password, salt = record.password, record.salt
        yield
        User.update_all({:password => password, :salt => salt}, ['id = ?', record])
      else
        yield
      end
    end
  end
end