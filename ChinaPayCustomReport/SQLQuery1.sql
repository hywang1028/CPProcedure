--if OBJECT_ID(N'Proc_Test', N'P') is not null
--begin
--	drop procedure Proc_Test;
--end
--go



----1. init variables & Procedure
--create procedure Proc_Test
--         @StartDate datetime = '2010-1-1',
--         @EndDate datetime ='2011-7-1',
--         @SumAmount decimal output,
--         @SumCount int output,
--         @BizType char(2) output
--as
--begin

----2. Check Input
--if(@StartDate is null or @EndDate is null)
--begin 
--      raiserror(N'Input params cannot be empty in Proc_Test',16,1);
--end		 

declare @StartDate datetime;
declare @EndDate datetime;
set @StartDate = '2011-01-01';
set @EndDate = '2011-07-01';


--3. Input Config Table
exec dbo.xprcFile
'MerchantName	BizType	OpenAccountDate	MerchantNo	ContractNo	Channel	BranchOffice
可口可乐（云南）饮料有限公司1（代扣）	代扣商户	20110511	808080450104703	DK-101002	银商	银联商务有限公司云南分公司
昆明统一企业食品有限公司（单笔代扣）	代扣商户	20110513	808080450104718	DK-101002	银商	银联商务有限公司云南分公司
云南捷汇通商贸有限公司-螺（单笔代扣）	代扣商户	20110526	808080450104759	DK-101002	银商	银联商务有限公司云南分公司
中国移动云南有限公司曲靖分公司（代扣）	代扣商户	20110511	808080450104702	DK-101002	银商	银联商务有限公司云南分公司
沈阳普罗米斯小额贷款有限责任公司（代扣）	代扣商户	20110408	808080450104576	DK-110401	银商	银联商务有限公司辽宁分公司
可口可乐辽宁（北）饮料有限公司[代扣]	代扣商户	20110523	808080450104748	DK-110507	银商	银联商务有限公司辽宁分公司
创野至易网络技术（北京）有限公司	ORA 商户	20110531	606060450100151	OL-110307	银商	北京银联商务有限公司
合肥通达旅行服务有限公司（预授权）	网上支付商户	20110524	808080510004754	OL-110340	银商	银联商务有限公司安徽分公司
北京童壹库网络科技有限公司	网上支付商户	20110415	808080580004597	OL-110412	银商	北京银联商务有限公司
北京汉方堂大药房有限公司	网上支付商户	20110421	808080580004611	OL-110416	银商	北京银联商务有限公司
一七网（北京）信息技术有限公司	网上支付商户	20110421	808080580004612	OL-110417	银商	北京银联商务有限公司
民生医药配送中心有限公司（B2B）	网上支付商户	20110526	808080580104761	OL-110516	银商	北京银联商务有限公司
民生医药配送中心有限公司（B2C）	网上支付商户	20110526	808080580104760	OL-110516	银商	北京银联商务有限公司
北京德商时代电子商务有限公司陕西分公司	网上支付商户	20110408	808080580104567	ORA-110402	银商	银联商务有限公司陕西分公司
北京市海淀区环球雅思培训学校	ORA 商户	20110519	606060430100147	ORA-110404	银商	北京银联商务有限公司
北京市海淀区环球雅思培训学校（代扣）	代扣商户	20110503	808080430104681	ORA-110404	银商	北京银联商务有限公司
重庆凯西来实业有限公司（代扣二期）	代扣商户	20110524	808080580104752	ORA-110407	银商	银联商务有限公司重庆分公司
重庆熙街购物中心管理有限公司（代扣二期）	代扣商户	20110524	808080580104753	ORA-110408	银商	银联商务有限公司重庆分公司
大连保税区亚联财小额贷款有限公司	代扣商户	20110128	808080450104340	Q-110103	银商	银联商务有限公司大连分公司
河南省正龙食品有限公司山西分公司	网上支付商户	20110127	808080450104339	tq-101101	银商	银联商务有限公司山西分公司
海南神鹿航空代理有限公司	网上支付商户	20110120	808080510104289	tq-101217	银商	银联商务有限公司海南分公司
万寿家（天津）食品有限公司	网上支付商户	20110425	808080580104628	TQ-110402	银商	银联商务有限公司天津分公司
三亚天涯客网络科技有限公司	网上支付商户	20110530	808080450104780	TQ-110501	银商	银联商务有限公司海南分公司
三亚天天假日旅行社有限公司	网上支付商户	20110530	808080520104777	TQ-110502	银商	银联商务有限公司海南分公司
';

select 
	MerchantName,
	BizType,
	CONVERT(datetime, OpenAccountDate) as OpenAccountDate,
	MerchantNo,
	ContractNo,
	Channel,
	BranchOffice
into
	#ConfigInput
from
	xlsContainer;




--4 Get SumAccount & SumCount from table(FactDailyTrans,Table_OraTransSum)

--4.1 Get FactDailyTrans SumAmount & SunCount
select 
      Merchants.MerchantNo,
      SUM(FDailyTran.SucceedTransAmount) as SumAmount,
      SUM(FDailyTran.SucceedTransCount) as SumCount
into
    #TemFactDaily
from
    #ConfigInput Merchants
    inner join
    FactDailyTrans FDailyTran
    on
      Merchants.MerchantNo = FDailyTran.MerchantNo     
where
    FDailyTran.DailyTransDate >= @StartDate
and
    FDailyTran.DailyTransDate < @EndDate
group by
    Merchants.MerchantNo;
    

--4.2 Get Table_OraTransSum SumAmount & SumCount
select
    Merchants.MerchantNo,
    SUM(OraTranSum.TransAmount) as SumAmount,
    SUM(OraTranSum.TransCount) as SumCount
into 
    #TemOra
from
    #ConfigInput Merchants
    inner join
    Table_OraTransSum OraTranSum
    on
    Merchants.MerchantNo = OraTranSum.MerchantNo
where
    OraTranSum.CPDate >= @StartDate
and
    OraTranSum.CPDate < @EndDate  
group by
    Merchants.MerchantNo;

     
--4.3 Get All SumAmount & SumCount
select * into #Temp from #TemFactDaily
union all
select * from #TemOra;
select 
	Merchants.*,
	isnull(Temp.SumAmount,0) SumAmount,
	isnull(Temp.SumCount,0) SumCount
into
	#MerchantsWithSum
from
	#ConfigInput Merchants
	left join
	#Temp Temp
	on
		Temp.MerchantNo = Merchants.MerchantNo;
--select
--      AllMerchants.*,
--      (ISNULL(TFDaily.SumAmount1,0) + ISNULL(TOra.SumAmount2,0)) as SumAmount,
--      (ISNULL(TFDaily.SumCount1,0) + ISNULL(TOra.SumCount2,0)) as SumCount
--into
--     #MerchantsWithSum
--from
--    #Config AllMerchants
--    left join
--    #TemFactDaily TFDaily
--    on
--      AllMerchants.MerchantNo = TFDaily.MerchantNo
--    left join
--    #TemOra TOra
--    on 
--      AllMerchants.MerchantNo = TOra.MerchantNo




--5 Caculate Average Sum
select
      MerWithSum.ContractNo,
      CONVERT(decimal,SUM(MerWithSum.SumAmount))/(DATEDIFF(month,MAX(MerWithSum.OpenAccountDate),@EndDate)-1) AvgAmount
into 
    #TemAvg
from
    #MerchantsWithSum MerWithSum
group by
    MerWithSum.ContractNo;



--6 Classified Merchants Level
select
      Merchants.MerchantName,
      Merchants.BizType,
      Merchants.OpenAccountDate,
      Merchants.MerchantNo,
      Merchants.ContractNo,
      Merchants.Channel,
      Merchants.BranchOffice,
      CONVERT(decimal,Merchants.SumAmount)/100 as SumAmount,
      Merchants.SumCount,
      CONVERT(decimal,TAvg.AvgAmount)/100 as AvgAmount,
      case when
               CONVERT(decimal,TAvg.AvgAmount)/100 >= 200000.00
      then 
           N'B'
      else
           N'C'
      end MerchantType      
from 
    #MerchantsWithSum Merchants
    inner join
    #TemAvg TAvg
    on
      Merchants.ContractNo = TAvg.ContractNo;
    

--7 Drop Temporary Tables    
drop table #ConfigInput
drop table #TemFactDaily
drop table #TemOra
drop table #MerchantsWithSum
drop table #TemAvg
drop table #Temp