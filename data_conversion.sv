package data_conversion;

	function integer to_integer(logic[21:0] number);
		return {32{22'(number)}};
	endfunction

endpackage
