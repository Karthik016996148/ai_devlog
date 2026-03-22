namespace :entries do
  desc "Process all pending/failed entries through the AI pipeline"
  task process_all: :environment do
    entries = Entry.where(processing_status: [:pending, :failed])
    puts "Found #{entries.count} entries to process"

    entries.find_each do |entry|
      print "Processing: #{entry.title} (ID=#{entry.id})... "
      begin
        EntryProcessingJob.perform_now(entry.id)
        entry.reload
        puts entry.processing_status
      rescue => e
        puts "FAILED: #{e.message}"
      end
    end

    puts "\nDone. Processed: #{Entry.processed.count}/#{Entry.count}"
  end
end
