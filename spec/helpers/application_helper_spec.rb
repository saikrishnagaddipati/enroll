require "rails_helper"

RSpec.describe ApplicationHelper, :type => :helper do

  describe "#dob_in_words" do
    it "returns date of birth in words for < 1 year" do
      expect(helper.dob_in_words(0, "20/06/2015".to_date)).to eq time_ago_in_words("20/06/2015".to_date)
      expect(helper.dob_in_words(0, "20/07/2015".to_date)).to eq time_ago_in_words("20/07/2015".to_date)
      expect(helper.dob_in_words(0, "20/07/2014".to_date)).to eq time_ago_in_words("20/07/2014".to_date)
    end
  end

  describe "#display_dental_metal_level" do
    let(:dental_plan_2015){FactoryGirl.create(:plan_template,:shop_dental, active_year: 2015)}
    let(:dental_plan_2016){FactoryGirl.create(:plan_template,:shop_dental, active_year: 2016)}

    it "should display metal level if its a 2015 plan" do
      expect(display_dental_metal_level(dental_plan_2015)).to eq dental_plan_2015.metal_level.titleize
    end

    it "should display metal level if its a 2016 plan" do
      expect(display_dental_metal_level(dental_plan_2016)).to eq dental_plan_2016.dental_level.titleize
    end
  end

  describe "#enrollment_progress_bar" do
    let(:employer_profile) { FactoryGirl.create(:employer_profile) }
    let(:plan_year) { FactoryGirl.create(:plan_year, employer_profile: employer_profile) }

    it "display progress bar" do
      expect(helper.enrollment_progress_bar(plan_year, 1, minimum: false)).to include('<div class="progress-wrapper employer-dummy">')
    end

    context ">100 census employees" do
      let!(:employees) { FactoryGirl.create_list(:census_employee, 101, employer_profile: employer_profile) }

      it "does not display" do
        expect(helper.enrollment_progress_bar(plan_year, 1, minimum: false)).to eq nil
      end
    end

  end

  describe "#fein helper methods" do
    it "returns fein with masked fein" do
      expect(helper.number_to_obscured_fein("111098222")).to eq "**-***8222"
    end

    it "returns formatted fein" do
      expect(helper.number_to_fein("111098222")).to eq "11-1098222"
    end
  end

  describe "date_col_name_for_broker_roaster" do
    context "for applicants controller" do
      before do
        expect(helper).to receive(:controller_name).and_return("applicants")
      end
      it "should return accepted date" do
        assign(:status, "active")
        expect(helper.date_col_name_for_broker_roaster).to eq 'Accepted Date'
      end
      it "should return terminated date" do
        assign(:status, "broker_agency_terminated")
        expect(helper.date_col_name_for_broker_roaster).to eq 'Terminated Date'
      end
      it "should return declined_date" do
        assign(:status, "broker_agency_declined")
        expect(helper.date_col_name_for_broker_roaster).to eq 'Declined Date'
      end
    end
    context "for other than applicants controller" do
      before do
        expect(helper).to receive(:controller_name).and_return("test")
      end
      it "should return certified" do
        assign(:status, "certified")
        expect(helper.date_col_name_for_broker_roaster).to eq 'Certified Date'
      end
      it "should return decertified" do
        assign(:status, "decertified")
        expect(helper.date_col_name_for_broker_roaster).to eq 'Decertified Date'
      end
      it "should return denied" do
        assign(:status, "denied")
        expect(helper.date_col_name_for_broker_roaster).to eq 'Denied Date'
      end
    end
  end

  describe "relationship_options" do
    let(:dependent) { double("FamilyMember") }

    context "consumer_portal" do
      it "should return correct options for consumer portal" do
        expect(helper.relationship_options(dependent, "consumer_role_id")).to match(/Domestic Partner/mi)
        expect(helper.relationship_options(dependent, "consumer_role_id")).to match(/other tax dependent/mi)
      end
    end

    context "employee portal" do
      it "should not match options that are in consumer portal" do
        expect(helper.relationship_options(dependent, "")).not_to match(/Domestic Partner/mi)
        expect(helper.relationship_options(dependent, "")).not_to match(/other tax dependent/mi)
      end
    end

  end

  describe "#is_readonly" do
    let(:user) { double("User") }
    let(:census_employee) { double("CensusEmployee") }
    before do
      expect(helper).to receive(:current_user).and_return(user)
    end
    it "census_employee can edit if it is new record" do
      expect(user).to receive(:roles).and_return(["employee"])
      expect(helper.is_readonly(CensusEmployee.new)).to eq false # readonly -> false
    end
    it "census_employee cannot edit if linked to an employer" do
      expect(user).to receive(:roles).and_return(["employee"])
      expect(census_employee).to receive(:employee_role_linked?).and_return(true)
      expect(helper.is_readonly(census_employee)).to eq true # readonly -> true
    end
    it "hbx admin edit " do
      expect(user).to receive(:roles).and_return(["hbx_staff"])
      expect(helper.is_readonly(CensusEmployee.new)).to eq false # readonly -> false
    end
  end

  describe "#parse_ethnicity" do
    it "should return string of values" do
      expect(helper.parse_ethnicity(["test", "test1"])).to eq "test, test1"
    end
    it "should return empty value if ethnicity is not selected" do
      expect(helper.parse_ethnicity([""])).to eq ""
    end
  end

  describe "#calculate_participation_minimum" do
    let(:plan_year_1) { double("PlanYear", eligible_to_enroll_count: 5) }
    before do
      @current_plan_year = plan_year_1
    end
    it "should  return 0 when eligible_to_enroll_count is zero" do
      expect(@current_plan_year).to receive(:eligible_to_enroll_count).and_return(0)
      expect(helper.calculate_participation_minimum).to eq 0
    end

    it "should calculate eligible_to_enroll_count when not zero" do
      expect(helper.calculate_participation_minimum).to eq 3
    end
  end

  describe "get_key_and_bucket" do
    it "should return array with key and bucket" do
      uri = "urn:openhbx:terms:v1:file_storage:s3:bucket:dchbx-sbc#f21369fc-ae6c-4fa5-a299-370a555dc401"
      key, bucket = get_key_and_bucket(uri)
      expect(key).to eq("f21369fc-ae6c-4fa5-a299-370a555dc401")
      expect(bucket).to eq("dchbx-sbc")
    end
  end
  describe "current_cost" do
    it "should return cost without session" do
      expect(helper.current_cost(100, 0.9)).to eq 100
    end

    context "with session" do
      before :each do
        session['elected_aptc'] = 100
        session['max_aptc'] = 200
      end

      it "when ehb_premium > aptc_amount" do
        expect(helper.current_cost(200, 0.9)).to eq (200 - 0.5*200)
      end

      it "when ehb_premium < aptc_amount" do
        expect(helper.current_cost(100, 0.9)).to eq (100 - 0.9*100)
      end

      it "should return 0" do
        session['elected_aptc'] = 160
        expect(helper.current_cost(100, 1.2)).to eq 0
      end

      it "when can_use_aptc is false" do
        expect(helper.current_cost(100, 1.2, nil, 'shopping', false)).to eq 100
      end

      it "when can_use_aptc is true" do
        expect(helper.current_cost(100, 1.2, nil, 'shopping', true)).to eq 0
      end
    end

    context "with hbx_enrollment" do
      let(:hbx_enrollment) {double(applied_aptc_amount: 10, total_premium: 100, coverage_kind: 'health')}
      it "should return cost from hbx_enrollment" do
        expect(helper.current_cost(100, 0.8, hbx_enrollment, 'account')).to eq 90
      end
    end
  end

  describe "env_bucket_name" do
    it "should return bucket name with system name prepended and environment name appended" do
      bucket_name = "sample-bucket"
      expect(env_bucket_name(bucket_name)).to eq("dchbx-enroll-" + bucket_name + "-local")
    end
  end

  describe "disable_purchase?" do
    it "should return true when disabled is true" do
      expect(helper.disable_purchase?(true, nil)).to eq true
    end

    context "when disable is false" do
      let(:hbx_enrollment) { HbxEnrollment.new }

      it "should return true when hbx_enrollment is not allow select_coverage" do
        allow(hbx_enrollment).to receive(:can_select_coverage?).and_return false
        expect(helper.disable_purchase?(false, hbx_enrollment)).to eq true
      end

      it "should return false when hbx_enrollment is allow select_coverage" do
        allow(hbx_enrollment).to receive(:can_select_coverage?).and_return true
        expect(helper.disable_purchase?(false, hbx_enrollment)).to eq false
      end
    end
  end

  describe "qualify_qle_notice" do
    it "should return notice" do
      expect(helper.qualify_qle_notice).to include("In order to purchase benefit coverage, you must be in either an Open Enrollment or Special Enrollment period. ")
    end
  end
end
