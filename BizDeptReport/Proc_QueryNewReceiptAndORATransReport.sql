--[Modified] on 2013-05-10 By 丁俊昊 Description:Add West Union Trans Data
if OBJECT_ID(N'Proc_QueryNewReceiptAndORATransReport',N'p')is not null
begin
	drop procedure Proc_QueryNewReceiptAndORATransReport
end
go

create procedure Proc_QueryNewReceiptAndORATransReport
	@StartDate datetime = '2012-12-16',
	@EndDate datetime = '2012-12-17',
	@BizType nvarchar(4) = N'全部'
as
begin


--1.check input
if(@StartDate is null or @EndDate is null or @BizType is null) 
begin
	raiserror(N'Input params cannot be empty in Proc_QueryNewReceiptAndORATransReport',16,1);
end


--2.Prepare EndDate
declare @CurrEndDate datetime;
set @CurrEndDate = DATEADD(DAY,1,@EndDate);

--2.1 Prepare TransType
create table #TransType
(
	TransType varchar(20)
);

if @BizType = N'代付'
begin
	insert into #TransType
	values
		('100002'),
		('100005');
end
else if @BizType = N'代收'
begin
	insert into #TransType
	values
		('100001'),
		('100004');
end
else
begin
	insert into #TransType
	values
		('100002'),
		('100005'),
		('100001'),
		('100004');;
end


--3.Prepare FinalyData
select
	s.MerchantNo,
	(select MerchantName from Table_TraMerchantInfo where MerchantNo = s.MerchantNo) as MerchantName,
	s.ChannelNo,
	(select ChannelName from Table_TraChannelConfig where ChannelNo = s.ChannelNo) as ChannelName,
	sum(s.CalFeeAmt)/100.0 as CalAmt,
	sum(s.CalCostCnt) as CalCnt,
	sum(s.FeeAmt)/100.0 as FeeAmt,
	sum(s.CostAmt)/100.0 as CostAmt
from
	Table_TraScreenSum s
where
	s.CPDate >= @StartDate
	and
	s.CPDate < @CurrEndDate
	and
	s.TransType in (select
					TransType
				from
					#TransType)
group by
	s.MerchantNo,
	s.ChannelNo;


drop table #TransType;

end