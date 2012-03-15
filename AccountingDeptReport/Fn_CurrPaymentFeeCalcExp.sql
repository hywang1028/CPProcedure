if OBJECT_ID(N'Fn_CurrPaymentFeeCalcExp',N'FN') is not null
begin
	drop function Fn_CurrPaymentFeeCalcExp;
end
go

create function Fn_CurrPaymentFeeCalcExp
(
	@MerchantNo varchar(20) = '100000000000001',
	@GateNo varchar(4) = '0002'
)
returns nvarchar(200)
as
begin
	declare @FeeCalcExp nvarchar(200);
	if exists (
		select
			1
		from
			Table_PaymentMerRate PaymentMerRate
		where
			PaymentMerRate.MerchantNo = @MerchantNo
			and
			PaymentMerRate.GateNo = @GateNo
			and
			PaymentMerRate.StartDate <= getdate()
			and
			PaymentMerRate.EndDate > getdate())
	begin
		set @FeeCalcExp = stuff(
			(select
			'，' +
			case when 
				PaymentMerRate.FeeType = 'Fixed'
				and
				PaymentMerRate.RefMinAmt = 0
				and
				PaymentMerRate.RefMaxAmt = 100000000000000
			then 
				N'每笔手续费' + convert(varchar, convert(decimal(10, 2), PaymentMerRate.FeeValue/100)) + N'元'
			when
				PaymentMerRate.FeeType = 'Fixed'
				and
				(PaymentMerRate.RefMinAmt <> 0
				 or
				 PaymentMerRate.RefMaxAmt <> 100000000000000) 
			then 
				N'每笔交易金额在'+ convert(varchar,convert(decimal(20,2),PaymentMerRate.RefMinAmt/100))  
				+ case when 
						   PaymentMerRate.RefMaxAmt != 100000000000000
					   then 
						   '-' + convert(varchar,convert(decimal(20,2),PaymentMerRate.RefMaxAmt/100)) + N'元时，'
					   else
						   N'以上时，'
				  end	
				     + N'每笔手续费' + convert(varchar, convert(decimal(10, 2), PaymentMerRate.FeeValue/100)) + N'元'
			when 
				PaymentMerRate.FeeType = 'Percent'
				and
				PaymentMerRate.RefMinAmt = 0
				and
				PaymentMerRate.RefMaxAmt = 100000000000000 
			then
				N'按金额的' + convert(varchar, convert(decimal(10, 2), PaymentMerRate.FeeValue * 100)) + N'%收取手续费' 
				+ case when 
						PaymentMerRate.BaseFeeAmt <> 0 
					then 
						N'，封底' + convert(varchar, convert(decimal(10, 2), PaymentMerRate.BaseFeeAmt)) + N'元'
					else
						'' 
					end
				+ case when 
						PaymentMerRate.PeakFeeAmt <> 0
					then 
						N'，封顶' + convert(varchar,convert(decimal(10, 2), PaymentMerRate.PeakFeeAmt)) + N'元' 
					else
						''
					end
			when
				PaymentMerRate.FeeType = 'Percent'
				and
				(PaymentMerRate.RefMinAmt <> 0
				 or
				 PaymentMerRate.RefMaxAmt <> 100000000000000) 
			then
				N'每笔交易金额在'+ convert(varchar,convert(decimal(20,2),PaymentMerRate.RefMinAmt/100))  
				+ case when 
					PaymentMerRate.RefMaxAmt != 100000000000000
				then 
					'-' + convert(varchar,convert(decimal(20,2),PaymentMerRate.RefMaxAmt/100)) + N'元时，'
				else
					N'以上时，'
				end	
				+ N'按金额的' + convert(varchar, convert(decimal(10, 2), PaymentMerRate.FeeValue * 100)) + N'%收取手续费'
				+ case when 
						PaymentMerRate.BaseFeeAmt <> 0 
					then 
						N'，封底' + convert(varchar, convert(decimal(10, 2), PaymentMerRate.BaseFeeAmt)) + N'元'
					else
						'' 
					end
				+ case when 
						PaymentMerRate.PeakFeeAmt <> 0
					then 
						N'，封顶' + convert(varchar,convert(decimal(10, 2), PaymentMerRate.PeakFeeAmt)) + N'元' 
					else
						''
					end
			End
		from
			Table_PaymentMerRate PaymentMerRate
		where
			PaymentMerRate.MerchantNo = @MerchantNo
			and
			PaymentMerRate.GateNo = @GateNo
			and
			PaymentMerRate.StartDate <= getdate()
			and
			PaymentMerRate.EndDate > getdate()
		for xml path('')),
		1,
		1,
		'')
	end		
	else
	begin
		set @FeeCalcExp = N'';
	end

	return @FeeCalcExp;
end


