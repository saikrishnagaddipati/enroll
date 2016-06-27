namespace :migrations do
  desc "create missing consumer roles for dependents"
  task :terminate_employer_account, [:fein, :termination_date] => :environment do |task, args|

    fein = args[:fein]
    organizations = Organization.where(fein: fein)

    if organizations.size > 1
      puts "found more than 1 for #{legal_name}"
      raise 'more than 1 employer found with given fein'
    end

    puts "Processing #{organizations.first.legal_name}"
    termination_date = Date.strptime(args[:termination_date], "%m/%d/%Y")

    organizations.each do |organization|

      # Expire previous year plan years
      organization.employer_profile.plan_years.published.where(:"end_on".lte => TimeKeeper.date_of_record).each do |plan_year|
        enrollments = enrollments_for_plan_year(plan_year)


        enrollments.each do |hbx_enrollment|
          hbx_enrollment.expire_coverage! if hbx_enrollment.may_expire_coverage?
          benefit_group_assignment = hbx_enrollment.benefit_group_assignment
          benefit_group_assignment.expire_coverage! if benefit_group_assignment.may_expire_coverage?
        end

        plan_year.expire! if plan_year.may_expire?
      end

      # Terminate current active plan years
      organization.employer_profile.plan_years.published_plan_years_by_date(TimeKeeper.date_of_record).each do |plan_year|

        enrollments = enrollments_for_plan_year(plan_year)
        if enrollments.any?
          puts "Terminating employees coverage for employer #{organization.legal_name}"
        end

        enrollments.each do |hbx_enrollment|
          if hbx_enrollment.may_terminate_coverage?
            hbx_enrollment.update_attributes(:terminated_on => termination_date)
            hbx_enrollment.terminate_coverage!
            # hbx_enrollment.propogate_terminate(termination_date)
          end
        end

        plan_year.update_attributes(:terminated_on => termination_date)
        plan_year.terminate! if plan_year.may_terminate?    
      end

      # organization.employer_profile.census_employees.non_terminated.each do |census_employee|
      #   if census_employee.employee_role_linked?
      #     census_employee.employee_role.delete
      #     census_employee.update_attributes(:aasm_state => 'eligible', :employee_role_id => nil)
      #   end
      #   if census_employee.active_benefit_group_assignment.present?
      #     census_employee.active_benefit_group_assignment.update_attributes(:is_active => false)
      #   end
      # end

      organization.employer_profile.revert_application! if organization.employer_profile.may_revert_application?
    end
  end


  task :clean_terminated_employers, [:fein, :termination_date] => :environment do |fein, termination_date|
    # employers = {
    #   "460820787" => "10/31/2015",
    #   "521954919" => "9/30/2015",
    #   "711024079" => "6/30/2015",
    #   "453460933" => "9/30/2015",
    #   "042730954" => "12/31/2015",
    #   "522227063" => "1/31/2016",
    #   "465220487" => "1/31/2016",
    #   "201146765" => "12/31/2015",
    #   "454161124" => "1/31/2016",
    #   "461825831" => "1/31/2016",
    #   "471408297" => "1/31/2016",
    #   "743162814" => "12/31/2015"
    # }

    # employers.each do |fein, termination_date|
      organizations = Organization.where(fein: fein)

      if organizations.size > 1
        puts "found more than 1 for #{legal_name}"
      end

      puts "Processing #{organizations.first.legal_name}"
      termination_date = Date.strptime(termination_date, "%m/%d/%Y")

      organizations.each do |organization|
        renewing_plan_year = organization.employer_profile.plan_years.renewing.first
         if renewing_plan_year.present?
           enrollments = enrollments_for_plan_year(renewing_plan_year)
           enrollments.each do |enrollment|
             enrollment.cancel_coverage!
           end

           puts "found renewing plan year for #{organization.legal_name}---#{renewing_plan_year.start_on}"
           renewing_plan_year.cancel_renewal! if renewing_plan_year.may_cancel_renewal?
          end
        end
      end
    end


def enrollments_for_plan_year(plan_year)
  id_list = plan_year.benefit_groups.map(&:id)
  families = Family.where(:"households.hbx_enrollments.benefit_group_id".in => id_list)
  enrollments = families.inject([]) do |enrollments, family|
    enrollments += family.active_household.hbx_enrollments.where(:benefit_group_id.in => id_list).any_of([HbxEnrollment::enrolled.selector, HbxEnrollment::renewing.selector]).to_a
  end
end