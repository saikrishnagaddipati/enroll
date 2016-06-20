require "rails_helper"

RSpec.describe Insured::FamiliesHelper, :type => :helper do

  describe "#plan_shopping_dependent_text" do
    let(:person) { FactoryGirl.build_stubbed(:person)}
    let(:family) { FactoryGirl.build_stubbed(:family, :with_primary_family_member, person: person) }
    let(:household) { FactoryGirl.build_stubbed(:household, family: family) }
    let(:hbx_enrollment) { FactoryGirl.build_stubbed(:hbx_enrollment, household: household, hbx_enrollment_members: [hbx_enrollment_member, hbx_enrollment_member_two]) }
    let(:hbx_enrollment_member) { FactoryGirl.build_stubbed(:hbx_enrollment_member) }
    let(:hbx_enrollment_member_two) { FactoryGirl.build_stubbed(:hbx_enrollment_member, is_subscriber: false) }


    it "it should return subscribers full name in span with dependent-text class" do
      allow(hbx_enrollment_member_two).to receive(:is_subscriber).and_return(true)
      allow(hbx_enrollment_member).to receive_message_chain("person.full_name").and_return("Bobby Boucher")
      expect(helper.plan_shopping_dependent_text(hbx_enrollment)).to eq "<span class='dependent-text'>Bobby Boucher</span>"
    end

    it "it should return subscribers and dependents modal" do
      allow(hbx_enrollment_member).to receive_message_chain("person.full_name").and_return("Bobby Boucher")
      allow(hbx_enrollment_member).to receive_message_chain("person.find_relationship_with").and_return("Spouse")
      allow(hbx_enrollment_member_two).to receive_message_chain("person.full_name").and_return("Danny Boucher")
      expect(helper.plan_shopping_dependent_text(hbx_enrollment)).to match '<h4 class="modal-title">Coverage For</h4>'
    end

  end

  describe "#generate_options_for_effective_on_kinds" do
    it "it should return blank array" do
      options = helper.generate_options_for_effective_on_kinds([], TimeKeeper.date_of_record)
      expect(options).to eq []
    end

    it "it should return options" do
      options = helper.generate_options_for_effective_on_kinds(['date_of_event', 'fixed_first_of_next_month'], TimeKeeper.date_of_record)
      date = TimeKeeper.date_of_record
      expect(options).to eq [[date.to_s, 'date_of_event'], [(date.end_of_month+1.day).to_s, 'fixed_first_of_next_month']]
    end
  end

  describe "#render_plan_type_details" do
    let(:dental_plan_2015){FactoryGirl.create(:plan_template,:shop_dental, active_year: 2015, metal_level: "dental")}
    let(:dental_plan_2016){FactoryGirl.create(:plan_template,:shop_dental, active_year: 2016, metal_level: "dental", dental_level: "high")}
    let(:health_plan_2016){FactoryGirl.create(:plan_template,:shop_health, active_year: 2016, metal_level: "silver")}

    it "should return dental plan with dental_level = high for 2016 plan" do
      expect(helper.render_plan_type_details(dental_plan_2016)).to eq "<label><span class=\"dental-icon\">High</span></label>"
    end

    it "should return dental plan with metal_level = dental for 2015 plan" do
      expect(helper.render_plan_type_details(dental_plan_2015)).to eq "<label><span class=\"dental-icon\">Dental</span></label>"
    end

    it "should return health plan with metal_level = bronze" do
      expect(helper.render_plan_type_details(health_plan_2016)).to eq "<label><span class=\"silver-icon\">Silver</span></label>"
    end
  end

  describe "#show_employer_panel" do
    let(:person) {FactoryGirl.build(:person)}
    let(:employee_role) {FactoryGirl.build(:employee_role)}
    let(:census_employee) {FactoryGirl.build(:census_employee)}
    let(:person_with_employee_role) {FactoryGirl.create(:person, :with_employee_role)}

    it "should return false without employee_role" do
      expect(helper.newhire_enrollment_eligible?(nil)).to eq false
    end

    it "should return false with employee_role who has no census_employee" do
      allow(employee_role).to receive(:census_employee).and_return nil
      expect(helper.newhire_enrollment_eligible?(employee_role)).to eq false
    end

    context "with employee_role who has census_employee" do
      before :each do
        allow(employee_role).to receive(:census_employee).and_return census_employee
      end

      it "should return false when census_employee is not newhire_enrollment_eligible" do
        allow(census_employee).to receive(:newhire_enrollment_eligible?).and_return false
        expect(helper.newhire_enrollment_eligible?(employee_role)).to eq false
      end

      context "when census_employee is newhire_enrollment_eligible" do
        before do
          allow(census_employee).to receive(:newhire_enrollment_eligible?).and_return true
        end

        it "should return false when person can not select coverage" do
          allow(employee_role).to receive(:can_select_coverage?).and_return false
          expect(helper.newhire_enrollment_eligible?(employee_role)).to eq false
        end

        it "should return true when person can select coverage" do
          allow(employee_role).to receive(:can_select_coverage?).and_return true
          expect(helper.newhire_enrollment_eligible?(employee_role)).to eq true
        end
      end
    end
  end

  describe "has_writing_agent?" do
    let(:employee_role) { FactoryGirl.build(:employee_role) }

    it "should return false" do
      expect(helper.has_writing_agent?(employee_role)).to eq false
    end
  end

  describe "display_aasm_state?" do
    let(:aasm_state1) {"shopping"}
    let(:aasm_state2) {"inactive"}
    let(:aasm_state3) {"unverified"}
    let(:aasm_state4) {"coverage_enrolled"}
    let(:aasm_state5) {"coverage_selected"}
    let(:aasm_state6) {"coverage_canceled"}
    let(:aasm_state7) {"coverage_terminated"}

    it "should return true" do
      expect(helper.display_aasm_state?(aasm_state5)).to eq true
      expect(helper.display_aasm_state?(aasm_state6)).to eq true
      expect(helper.display_aasm_state?(aasm_state7)).to eq true
    end

    it "should return false" do
      expect(helper.display_aasm_state?(aasm_state1)).to be_falsey
      expect(helper.display_aasm_state?(aasm_state2)).to be_falsey
      expect(helper.display_aasm_state?(aasm_state3)).to be_falsey
      expect(helper.display_aasm_state?(aasm_state4)).to be_falsey
    end  
  end
end
