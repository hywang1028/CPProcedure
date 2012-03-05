if Object_ID(N'Proc_CalORAFee',N'P') is not null
begin
	drop procedure Proc_CalORAFee;
end
go

create procedure Proc_CalORAFee
	@StartDate datetime = '2011-01-01',
	@EndDate datetime = '2011-12-31'
as
begin

declare @CurrStartDate datetime;
declare @CurrEndDate datetime;

set @CurrStartDate = @StartDate;
set @CurrEndDate = DATEADD(DAY, 1, @EndDate);

--1. Get Ora Trans 
select
	MerchantNo,
	TransCount,
	TransAmount,
	FeeAmount,
	CPDate,
	BankSettingID,
	convert(decimal(15, 4), 0) ActualFeeAmt
into
	#OraSum
from
	Table_OraTransSum
where
	CPDate >= @CurrStartDate
	and
	CPDate < @CurrEndDate;
	

--2. Calculate FeeAmount By Monthly Trans Count And Fixed FeeValue 
--2.1 Calculate Per Count FeeAmount
update
	Ora
set
	Ora.ActualFeeAmt = Ora.TransCount * OrdiMerRate.FeeValue
from
	#OraSum Ora
	inner join
	Table_OraOrdinaryMerRate OrdiMerRate
	on
		Ora.MerchantNo = OrdiMerRate.MerchantNo
		and
		Ora.CPDate >= OrdiMerRate.StartDate
		and
		Ora.CPDate < OrdiMerRate.EndDate
where
	OrdiMerRate.RefType = 'PerCnt';	
	

--2.2 Calculate Monthly Count FeeAmount
With MonthCntMer as
(
	select distinct
		MerchantNo		
	from	
		Table_OraOrdinaryMerRate
	where
		RefType = 'MonthCnt'
),
MonthlySumCnt as
(
	select
		Ora.MerchantNo,
		YEAR(Ora.CPDate) YearPart,
		MONTH(Ora.CPDate) MonthPart,
		SUM(Ora.TransCount) MonthlyCount
	from
		#OraSum Ora
		inner join
		MonthCntMer Mer
		on
			Ora.MerchantNo = Mer.MerchantNo
	group by
		Ora.MerchantNo,
		Year(Ora.CPDate),
		Month(Ora.CPDate)
)
update
	Ora
set
	Ora.ActualFeeAmt = Ora.TransCount * OrdiMerRate.FeeValue
from
	#OraSum Ora
	inner join
	MonthlySumCnt
	on
		Ora.MerchantNo = MonthlySumCnt.MerchantNo
		and
		Year(Ora.CPDate) = MonthlySumCnt.YearPart
		and
		Month(Ora.CPDate) = MonthlySumCnt.MonthPart
	inner join
	Table_OraOrdinaryMerRate OrdiMerRate
	on
		Ora.MerchantNo = OrdiMerRate.MerchantNo
		and
		Ora.CPDate >= OrdiMerRate.StartDate
		and
		Ora.CPDate < OrdiMerRate.EndDate
		and
		MonthlySumCnt.MonthlyCount > OrdiMerRate.RefMin
		and
		MonthlySumCnt.MonthlyCount <= OrdiMerRate.RefMax
where
	OrdiMerRate.RefType = 'MonthCnt'
	and
	Ora.ActualFeeAmt = 0;
	

--3. Calculate FeeAmount By Single Trans Amount And Percent FeeValue
update
	Ora
set
	Ora.ActualFeeAmt = case when 
							Ora.TransAmount * OrdiMerRate.FeeValue <= OrdiMerRate.RefMin
						then
							OrdiMerRate.RefMin
						when
							Ora.TransAmount * OrdiMerRate.FeeValue >= OrdiMerRate.RefMax
						then
							OrdiMerRate.RefMax
						else
							Ora.TransAmount * OrdiMerRate.FeeValue
						end
from
	#OraSum Ora
	inner join
	Table_OraOrdinaryMerRate OrdiMerRate
	on
		Ora.MerchantNo = OrdiMerRate.MerchantNo
		and
		Ora.CPDate >= OrdiMerRate.StartDate
		and
		Ora.CPDate < OrdiMerRate.EndDate
where
	Ora.ActualFeeAmt = 0
	and
	OrdiMerRate.RefType = 'Percent';


--4.Calculate FeeAmount By BankName FeeValue
update
	Ora
set
	Ora.ActualFeeAmt = Ora.TransCount * BankMerRate.FeeValue
from
	#OraSum Ora
	inner join
	Table_OraBankMerRate BankMerRate
	on
		Ora.MerchantNo = BankMerRate.MerchantNo
		and
		Ora.CPDate >= BankMerRate.StartDate
		and
		Ora.CPDate < BankMerRate.EndDate
	inner join
	Table_OraBankSetting BankSetting
	on
		BankSetting.BankName like BankMerRate.BankName	
where
	Ora.ActualFeeAmt = 0;
	
update
	Ora
set
	Ora.ActualFeeAmt = Ora.TransCount * BankMerRate.FeeValue
from
	#OraSum Ora
	inner join
	Table_OraBankMerRate BankMerRate
	on
		Ora.MerchantNo = BankMerRate.MerchantNo
		and
		Ora.CPDate >= BankMerRate.StartDate
		and
		Ora.CPDate < BankMerRate.EndDate	
where
	Ora.ActualFeeAmt = 0
	and
	BankMerRate.BankName = N'ÆäËû';
	
	
select
	MerchantNo,
	BankSettingID,
	CPDate,
	TransCount,
	TransAmount,
	FeeAmount,
	ActualFeeAmt
from
	#OraSum;


drop table #OraSum;


end



	

