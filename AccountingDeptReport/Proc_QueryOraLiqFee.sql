--[Created] At 20120531 By ¶¡¿¡ê»£ºProc_QueryOraLiqFee
--Input:@StartDate,@EndDate;
--Output:MerchantName,MerchantNo,LiqDate,UploadAmt,TransCount,FeeAmt,Memo
if OBJECT_ID(N'Proc_QueryOraLiqFee',N'P')is not null
begin
	drop procedure Proc_QueryOraLiqFee
end
go


Create procedure Proc_QueryOraLiqFee
	@StartDate datetime,
	@EndDate datetime
as
begin


--1.Check Input
if (@StartDate is null or @EndDate is null)
begin 
raiserror(N'Input params cannot be empty in Proc_QueryOraLiqFee',16,1)
end


--2.Prepare @StartDate and @EndDate
declare @CurrEndDate datetime;
set @CurrEndDate = DATEADD(DAY,1,@EndDate)


--3.Limit Table OraTrans Data
select
	MerchantNo,
	LiqDate,
	TransDate,
	UploadAmt,
	FeeAmt
into
	#OraLiqLogLiqDate
from
	Table_OraLiqLog
where
	TransDate >= @StartDate
	and
	TransDate < @CurrEndDate


--4.Limit Table_OraTransSum Data
select
	MerchantNo,
	SUM(TransCount) TransCount,
	CPDate
into
	#OraTransSumCPDate
from
	Table_OraTransSum
where
	CPDate >= @StartDate
	and
	CPDate < @CurrEndDate
group by
	MerchantNo,
	CPDate


--5.Limit Tontact Time and MerchantNo
select
	IDENTITY(int,1,1) as Number,
	coalesce(OraLiqLogLiqDate.MerchantNo,OraTransSumCPDate.MerchantNo) MerchantNo,
	coalesce(OraLiqLogLiqDate.TransDate,OraTransSumCPDate.CPDate) LiqDate,
	ISNULL(OraLiqLogLiqDate.UploadAmt,0) UploadAmt,
	ISNULL(OraTransSumCPDate.TransCount,0) TransCount,
	ISNULL(OraLiqLogLiqDate.FeeAmt,0) FeeAmt
into
	#ORALiqDateFinal
from
	#OraLiqLogLiqDate OraLiqLogLiqDate
	full outer join
	#OraTransSumCPDate OraTransSumCPDate
	on
		OraLiqLogLiqDate.MerchantNo = OraTransSumCPDate.MerchantNo
		and
		OraLiqLogLiqDate.TransDate = OraTransSumCPDate.CPDate
order by
	MerchantNo,
	LiqDate


--6.Count FeeAmt	
update
	ORALiqDateFinal
set
	ORALiqDateFinal.FeeAmt = OraAdditionalFeeRule.FeeValue * ORALiqDateFinal.TransCount
from
	#ORALiqDateFinal ORALiqDateFinal
	inner join
	Table_OraAdditionalFeeRule OraAdditionalFeeRule
	on
		ORALiqDateFinal.MerchantNo = OraAdditionalFeeRule.MerchantNo;


--7.Get MerchantName and Memo	
select  
	ORALiqDateFinal.Number,
	Table_OraMerchants.MerchantName,
	ORALiqDateFinal.MerchantNo,
	ORALiqDateFinal.LiqDate,
	ORALiqDateFinal.UploadAmt/100.0 UploadAmt,
	(ORALiqDateFinal.TransCount) TransCount,
	ORALiqDateFinal.FeeAmt/100.0 FeeAmt,
	isnull(OraAdditionalFeeRule.Memo,N'') Memo
from
	#ORALiqDateFinal ORALiqDateFinal
	left join
	Table_OraMerchants
	on
		ORALiqDateFinal.MerchantNo = Table_OraMerchants.MerchantNo
	left join
	Table_OraAdditionalFeeRule OraAdditionalFeeRule
	on
		ORALiqDateFinal.MerchantNo = OraAdditionalFeeRule.MerchantNo


end