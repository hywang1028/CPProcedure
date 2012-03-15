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
			'��' +
			case when 
				PaymentMerRate.FeeType = 'Fixed'
				and
				PaymentMerRate.RefMinAmt = 0
				and
				PaymentMerRate.RefMaxAmt = 100000000000000
			then 
				N'ÿ��������' + convert(varchar, convert(decimal(10, 2), PaymentMerRate.FeeValue/100)) + N'Ԫ'
			when
				PaymentMerRate.FeeType = 'Fixed'
				and
				(PaymentMerRate.RefMinAmt <> 0
				 or
				 PaymentMerRate.RefMaxAmt <> 100000000000000) 
			then 
				N'ÿ�ʽ��׽����'+ convert(varchar,convert(decimal(20,2),PaymentMerRate.RefMinAmt/100))  
				+ case when 
						   PaymentMerRate.RefMaxAmt != 100000000000000
					   then 
						   '-' + convert(varchar,convert(decimal(20,2),PaymentMerRate.RefMaxAmt/100)) + N'Ԫʱ��'
					   else
						   N'����ʱ��'
				  end	
				     + N'ÿ��������' + convert(varchar, convert(decimal(10, 2), PaymentMerRate.FeeValue/100)) + N'Ԫ'
			when 
				PaymentMerRate.FeeType = 'Percent'
				and
				PaymentMerRate.RefMinAmt = 0
				and
				PaymentMerRate.RefMaxAmt = 100000000000000 
			then
				N'������' + convert(varchar, convert(decimal(10, 2), PaymentMerRate.FeeValue * 100)) + N'%��ȡ������' 
				+ case when 
						PaymentMerRate.BaseFeeAmt <> 0 
					then 
						N'�����' + convert(varchar, convert(decimal(10, 2), PaymentMerRate.BaseFeeAmt)) + N'Ԫ'
					else
						'' 
					end
				+ case when 
						PaymentMerRate.PeakFeeAmt <> 0
					then 
						N'���ⶥ' + convert(varchar,convert(decimal(10, 2), PaymentMerRate.PeakFeeAmt)) + N'Ԫ' 
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
				N'ÿ�ʽ��׽����'+ convert(varchar,convert(decimal(20,2),PaymentMerRate.RefMinAmt/100))  
				+ case when 
					PaymentMerRate.RefMaxAmt != 100000000000000
				then 
					'-' + convert(varchar,convert(decimal(20,2),PaymentMerRate.RefMaxAmt/100)) + N'Ԫʱ��'
				else
					N'����ʱ��'
				end	
				+ N'������' + convert(varchar, convert(decimal(10, 2), PaymentMerRate.FeeValue * 100)) + N'%��ȡ������'
				+ case when 
						PaymentMerRate.BaseFeeAmt <> 0 
					then 
						N'�����' + convert(varchar, convert(decimal(10, 2), PaymentMerRate.BaseFeeAmt)) + N'Ԫ'
					else
						'' 
					end
				+ case when 
						PaymentMerRate.PeakFeeAmt <> 0
					then 
						N'���ⶥ' + convert(varchar,convert(decimal(10, 2), PaymentMerRate.PeakFeeAmt)) + N'Ԫ' 
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


