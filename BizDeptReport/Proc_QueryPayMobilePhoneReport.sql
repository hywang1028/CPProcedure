--[Modified] at 2013-07-22 by ����� Description:Add FeeAmtData and CostAmtData
if OBJECT_ID(N'Proc_QueryPayMobilePhoneReport',N'P') is not null
begin
	drop procedure Proc_QueryPayMobilePhoneReport;
end
go


create procedure Proc_QueryPayMobilePhoneReport
	@StartDate datetime = '2013-01-11',
	@PeriodUnit Nchar(3) = N'�Զ���',
	@EndDate datetime = '2013-03-12'
as
begin

--1.
--Ŀ�ģ����ʱ������Ƿ�Ϊ��
--�������������Ϣ
--���ȣ���
--��������
if(@StartDate is null)
begin
	raiserror(N'Input params can`t be empty in Proc_QueryPayMobilePhoneReport',16,1);  
end

declare @CurrStartDate datetime;
declare @CurrEndDate datetime;


if(@PeriodUnit = N'��')  
begin  
	set @CurrStartDate = @StartDate;  
	set @CurrEndDate = DATEADD(WEEK,1,@StartDate);  
end  
else if(@PeriodUnit = N'��')  
begin  
	set @CurrStartDate = @StartDate;  
	set @CurrEndDate = DATEADD(MONTH,1,@StartDate);  
end  
else if(@PeriodUnit = N'����')  
begin  
	set @CurrStartDate = @StartDate;  
	set @CurrEndDate = DATEADD(QUARTER,1,@StartDate);  
end  
else if(@PeriodUnit = N'����')  
begin  
	set @CurrStartDate = @StartDate;  
	set @CurrEndDate = DATEADD(MONTH,6,@StartDate);  
end  
else if(@PeriodUnit = N'��')  
begin  
	set @CurrStartDate = @StartDate;  
	set @CurrEndDate = DATEADD(YEAR,1,@StartDate);  
end  
else if(@PeriodUnit = N'�Զ���')  
begin  
	set @CurrStartDate = @StartDate;  
	set @CurrEndDate = DATEADD(day,1,@EndDate);  
end;  


--1.1
--Ŀ�ģ�׼���ɱ����ݺ��������ݵ�ͳ�Ƽ���
--�������#UPOPCostAndFeeData  
--���ȣ����غš��̻���  
--������GateNo��MerchantNo��TransDate��CdFlag��TransAmt��TransCnt��FeeAmt��CostAmt
create table #UPOPCostAndFeeData
	(
		GateNo char(6),
		MerchantNo varchar(25),
		TransDate datetime,
		CdFlag	char(5),
		TransAmt decimal(16,2),
		TransCnt bigint,
		FeeAmt decimal(16,2),
		CostAmt decimal(18,4)
	)
begin
	insert into #UPOPCostAndFeeData
	(	
		GateNo,
		MerchantNo,
		TransDate,
		CdFlag,
		TransAmt,
		TransCnt,
		FeeAmt,
		CostAmt
	)
	exec Proc_CalUPOPCost
		@CurrStartDate,
		@CurrEndDate
end;


--2.  
--Ŀ�ģ�999920130320153������������CP�̻��Ŷ�Ӧ�û����ñ��е�UPOP�̻��š�  
--�������#InstuNoMer  
--���ȣ��̻���  
--������CPMerchantNo��UpopMerNo  
with InstuNo as  
(  
	select  
		MerchantNo CPMerchantNo  
	from  
		Table_InstuMerInfo  
	where  
		InstuNo = '999920130320153'  
)  
select  
	Table_CpUpopRelation.CpMerNo CPMerchantNo,  
	Table_CpUpopRelation.UpopMerNo  
into  
	#InstuNoMer
from
	Table_CpUpopRelation
	inner join
	InstuNo
	on
		InstuNo.CPMerchantNo = Table_CpUpopRelation.CpMerNo;


--3.
--Ŀ�ģ��ó������  
--�������#AllData  
--���ȣ�һ�����غŶ�Ӧһ���̻��Ŷ�Ӧһ�����ܼ�¼  
--������CPMerchantNo��CPMerchantName��UpopMerNo��UPOPMerchantName��OpenTime��GateNo��TransAmt��TransCnt
select  
	T.CPMerchantNo,  
	CP.MerchantName CPMerchantName,  
	T.UpopMerNo,  
	UPOP.MerchantName UPOPMerchantName,  
	CP.OpenTime,  
	U.GateNo,  
	SUM(U.PurAmt)/1000000.0 TransAmt,  
	SUM(U.PurCnt)/10000.0 TransCnt
into
	#AllData
from
	#InstuNoMer T
	left join
	Table_UpopliqFeeLiqResult U
	on
		T.UpopMerNo = U.MerchantNo
	left join
	Table_MerInfo CP
	on
		T.CPMerchantNo = CP.MerchantNo
	left join
	Table_UpopliqMerInfo UPOP
	on
		T.UpopMerNo = UPOP.MerchantNo
where
	TransDate >= @CurrStartDate
	and
	TransDate < @CurrEndDate
group by
	T.CPMerchantNo,
	CP.MerchantName,
	T.UpopMerNo,
	UPOP.MerchantName,
	CP.OpenTime,
	U.GateNo
order by
	T.UpopMerNo;


--4. Prepare #UPOPCostAndFeeData SUMData
select
	 GateNo,
	 MerchantNo,
	 SUM(CostAmt) CostAmt,
	 SUM(FeeAmt) FeeAmt
into
	#SUMUpopCostAndFee
from 
	#UPOPCostAndFeeData
group by
	GateNo,
	MerchantNo;


--4. Result
with Result as
(
select
	#InstuNoMer.CPMerchantNo,
	coalesce(CPMerchantName,CP.MerchantName) CPMerchantName,
	#InstuNoMer.UpopMerNo,
	coalesce(UPOPMerchantName,UPOP.MerchantName) UPOPMerchantName,
	coalesce(#AllData.OpenTime,UPOP.OpenDate,CP.OpenTime) OpenTime,
	#AllData.GateNo,
	#AllData.TransAmt,
	#AllData.TransCnt
from
	#InstuNoMer
	left join
	#AllData
	on
		#InstuNoMer.CPMerchantNo =  #AllData.CPMerchantNo
		left join
		Table_UpopliqMerInfo UPOP
	on
		#InstuNoMer.UpopMerNo = UPOP.MerchantNo
	left join
	Table_MerInfo CP
	on
		#InstuNoMer.CPMerchantNo = CP.MerchantNo
)
	select
		Result.CPMerchantNo,
		Result.CPMerchantName,
		Result.UpopMerNo,
		Result.UPOPMerchantName,
		Result.OpenTime,
		Result.GateNo,
		Result.TransAmt,
		Result.TransCnt,
		#SUMUpopCostAndFee.FeeAmt/100.0 FeeAmt,
		#SUMUpopCostAndFee.CostAmt/100.0 CostAmt
	from
		Result
		left join
		#SUMUpopCostAndFee
		on
			Result.UpopMerNo = #SUMUpopCostAndFee.MerchantNo
			and
			Result.GateNo = #SUMUpopCostAndFee.GateNo;


end