if OBJECT_ID(N'Proc_QueryCPBizProductData', N'P') is not null
begin
	drop procedure Proc_QueryCPBizProductData;
end
go

create procedure Proc_QueryCPBizProductData  
 @StartDate datetime = '2011-08-01',  
 @EndDate datetime = '2011-08-31'  
as  
begin  
  
--1. Check input  
if (@StartDate is null or @EndDate is null)  
begin  
 raiserror(N'Input params cannot be empty in Proc_QueryCPBizProductData', 16, 1);  
end  
  
--2. Prepare StartDate and EndDate  
declare @CurrStartDate datetime;  
declare @CurrEndDate datetime;  
  
set @CurrStartDate = @StartDate;  
set @CurrEndDate = DateAdd(day,1,@EndDate);  
  
--3. Prepare all the data  
--3.1 Prepare Payment Data  
With ValidPayData as  
(  
 select   
  Trans.DailyTransDate TransDate,  
  SUM(Trans.SucceedTransCount) as TransCount,  
  SUM(Trans.SucceedTransAmount) as TransAmt  
 from  
  FactDailyTrans Trans  
 where  
  Trans.DailyTransDate >= @CurrStartDate  
  and  
  Trans.DailyTransDate < @CurrEndDate  
 group by  
  Trans.DailyTransDate  
),  
InvalidPayData as  
(  
 select   
  DailyTransLog_Date TransDate,  
  SUM(DailyTransLog_SucceedTransCount) as TransCount,  
  SUM(DailyTransLog_SucceedTransAmount) as TransAmt  
 from  
  Table_InvalidDailyTrans  
 where  
  DailyTransLog_Date >= @CurrStartDate  
  and  
  DailyTransLog_Date < @CurrEndDate  
 group by  
  DailyTransLog_Date  
)  
select  
 N'支付类数据' as DataType,  
 Convert(decimal,(SUM(ISNULL(Data.TransAmt,0))+SUM(ISNULL(Invalid.TransAmt,0))))/100 TransAmt,  
 SUM(ISNULL(Data.TransCount,0))+SUM(ISNULL(Invalid.TransCount,0)) TransCount,  
 N'商户控台->交易汇总统计->选择商户日期' as CPLocation  
into  
 #PaymentData  
from  
 ValidPayData Data  
 full outer join  
 InvalidPayData Invalid  
 on  
  Data.TransDate = Invalid.TransDate;  
    
--3.2 Prepare ORA Data  
select  
 N'代付数据' as DataType,  
 Convert(decimal,SUM(TransAmount))/100 TransAmt,  
 SUM(TransCount) TransCount,  
 N'ORA平台->存款管理->商户统计报表->选择CP日期->统计方式选择“自定义区间”' as CPLocation  
into  
 #OraTransData  
from  
 Table_OraTransSum  
where  
 CPDate >= @CurrStartDate  
 and  
 CPDate < @CurrEndDate;  
  
--3.3 Prepare WU Data  
select  
 N'西联汇款数据' as DataType,  
 Convert(decimal,SUM(DestTransAmount))/100 TransAmt,  
 COUNT(DestTransAmount) TransCount,  
 N'ORA平台->西联业务管理->交易明细查询->选择CP日期' as CPLocation  
into  
 #WUTransData  
from  
 Table_WUTransLog  
where  
 CPDate >= @CurrStartDate  
 and  
 CPDate < @CurrEndDate;  
   
--3.4 Prepare Fund and Transfer Data  
select  
 N'基金转账数据' as DataType,  
 Convert(decimal,SUM(TransAmt))/100 TransAmt,  
 COUNT(TransAmt) TransCount,  
 N'商户控台->全国转账交易明细->选择交易日期->网关应答选择“成功”' as CPLocation  
into  
 #TrfTransData  
from  
 Table_TrfTransLog  
where  
 TransDate >= @CurrStartDate  
 and  
 TransDate < @CurrEndDate;  
   
--4. Join the data together  
select * from #PaymentData  
union all  
select * from #OraTransData  
union all  
select * from #WUTransData  
union all  
select * from #TrfTransData;  
  
--5. Drop temp table  
drop table #PaymentData;  
drop table #OraTransData;  
drop table #WUTransData;  
drop table #TrfTransData;  
  
End