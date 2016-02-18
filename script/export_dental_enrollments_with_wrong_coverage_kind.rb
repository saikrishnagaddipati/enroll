# ticket https://devops.dchbx.org/redmine/issues/5142
# this script will export family, hbx_enrollment, plan details for dental plans having coverage kind as health

csv = CSV.open("dental_plans_in_shop.csv", "w")
csv << %w(hbx_enrollment.household.family.id, hbx_enrollment.hbx_id, hbx_enrollment.plan.name,
          hbx_enrollment.coverage_kind, hbx_enrollment.plan.coverage_kind hbx_enrollment.kind hbx_enrollment.created_at
          hbx_enrollment.aasm_state subscriber is_active?)

batch_size = Family.count/10
offset = 0

while offset < Family.count
  Family.offset(offset).limit(batch_size).flat_map(&:households).flat_map(&:hbx_enrollments).each do |hbx_enrollment|
    begin
      if hbx_enrollment.coverage_kind != hbx_enrollment.plan.coverage_kind
        if hbx_enrollment.subscriber
          subscriber_person = hbx_enrollment.subscriber.person
          subscriber = subscriber_person.first_name + " " + (subscriber_person.middle_name || "") + " " + subscriber_person.last_name
        else
          subscriber = ""
        end

        csv << [hbx_enrollment.household.family.id, hbx_enrollment.hbx_id,
                hbx_enrollment.plan.name, hbx_enrollment.coverage_kind, hbx_enrollment.plan.coverage_kind,
                hbx_enrollment.kind, hbx_enrollment.created_at, hbx_enrollment.aasm_state, subscriber, hbx_enrollment.is_active]
      end
    rescue Exception => e
      puts "#{hbx_enrollment.household.family.id} #{hbx_enrollment.hbx_id} " + e.message
    end
  end
  offset += batch_size
end