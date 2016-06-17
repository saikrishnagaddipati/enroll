var ManageFamilies = (function (window){
	function appendDependentQuestions(select){
	 option = select.value;
	 var dependent_list = [ "niece", "grandchild", 'nephew'];
	 // get age from DOB

	 if(jQuery.inArray(option,dependent_list) ==  0 ) {
	 	// appened question 	

	 }
	}
	return {
		appendDependentQuestions : appendDependentQuestions
	}
})(window);