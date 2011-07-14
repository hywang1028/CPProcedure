--1. Get 2009-2010 Data
select 
	N'2011年前交易量' as ItemName,
	MerchantNo,
	SUM(SucceedTransAmount) SucceedTransAmount, 
	SUM(SucceedTransCount) SucceedTransCount
into
	#DataIn2009
from 
	FactDailyTrans
where
	DailyTransDate >= '2009-01-01'
	and
	DailyTransDate < '2011-01-01'
group by
	MerchantNo;

--2. Get 2011-01 Data
select 
	N'2011年1月交易量' as ItemName,
	MerchantNo,
	SUM(SucceedTransAmount) SucceedTransAmount, 
	SUM(SucceedTransCount) SucceedTransCount
into
	#DataIn201101
from 
	FactDailyTrans
where
	DailyTransDate >= '2011-01-01'
	and
	DailyTransDate < '2011-02-01'
group by
	MerchantNo;
	
--3. Get 2011-02 Data
select 
	N'2011年2月交易量' as ItemName,
	MerchantNo,
	SUM(SucceedTransAmount) SucceedTransAmount, 
	SUM(SucceedTransCount) SucceedTransCount
into
	#DataIn201102
from 
	FactDailyTrans
where
	DailyTransDate >= '2011-02-01'
	and
	DailyTransDate < '2011-03-01'
group by
	MerchantNo;
	
--4. Get 2011-03 Data
select 
	N'2011年3月交易量' as ItemName,
	MerchantNo,
	SUM(SucceedTransAmount) SucceedTransAmount, 
	SUM(SucceedTransCount) SucceedTransCount
into
	#DataIn201103
from 
	FactDailyTrans
where
	DailyTransDate >= '2011-03-01'
	and
	DailyTransDate < '2011-04-01'
group by
	MerchantNo;
	
--5. Get 2011-04 Data
select 
	N'2011年4月交易量' as ItemName,
	MerchantNo,
	SUM(SucceedTransAmount) SucceedTransAmount, 
	SUM(SucceedTransCount) SucceedTransCount
into
	#DataIn201104
from 
	FactDailyTrans
where
	DailyTransDate >= '2011-04-01'
	and
	DailyTransDate < '2011-05-01'
group by
	MerchantNo;
	
--6. Get 2011-05 Data
select 
	N'2011年5月交易量' as ItemName,
	MerchantNo,
	SUM(SucceedTransAmount) SucceedTransAmount, 
	SUM(SucceedTransCount) SucceedTransCount
into
	#DataIn201105
from 
	FactDailyTrans
where
	DailyTransDate >= '2011-05-01'
	and
	DailyTransDate < '2011-06-01'
group by
	MerchantNo;
	
--7. Get 2011 01-05 Data
select 
	N'2011年1-5月汇总交易量' as ItemName,
	MerchantNo,
	SUM(SucceedTransAmount) SucceedTransAmount, 
	SUM(SucceedTransCount) SucceedTransCount
into
	#DataIn20110105
from 
	FactDailyTrans
where
	DailyTransDate >= '2011-01-01'
	and
	DailyTransDate < '2011-06-01'
group by
	MerchantNo;
	
--8. Union All
select * into #ResultTable from #DataIn2009
union all
select * from #DataIn2010
union all
select * from #DataIn201101
union all
select * from #DataIn201102
union all
select * from #DataIn201103
union all
select * from #DataIn201104
union all
select * from #DataIn201105
union all
select * from #DataIn20110105;

--9.
select
	Result.ItemName,
	Result.MerchantNo,
	convert(decimal,isnull(Result.SucceedTransAmount,0))/100 as SucceedTransAmount,
	ISNULL(Result.SucceedTransCount,0) as SucceedTransCount,
	Sales.MerchantName,
	Sales.Channel,
	Sales.BranchOffice,
	Sales.MerchantType,
	Sales.SigningYear
from
	#ResultTable Result
	left join
	Table_SalesDeptConfiguration Sales
	on
		Result.MerchantNo = Sales.MerchantNo;
		
drop table #DataIn2009;
drop table #DataIn2010;
drop table #DataIn201101;
drop table #DataIn201102;
drop table #DataIn201103;
drop table #DataIn201104;
drop table #DataIn201105;
drop table #DataIn20110105;

drop table #ResultTable;
