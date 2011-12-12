if OBJECT_ID(N'Proc_QueryGateNoCostRule', N'P') is not null
begin
	drop procedure Proc_QueryGateNoCostRule;
end
go

create procedure Proc_QueryGateNoCostRule
as
begin

--1.Declare @MAX
Declare @MAX bigint;
set @MAX = 100000000000000;


--2.Get Detail Rule
--2.1 By Trans
select 
	ByTrans.GateNo,
	ByTrans.ApplyDate,
	case when ByTrans.RefMinAmt = 0 and ByTrans.RefMaxAmt = @MAX
	then (case when ByTrans.FeeType = 'Fixed' 
			then N'固定按每笔' + RTrim(Convert(char,Convert(Decimal(15,2),ByTrans.FeeValue/100))) + N'元计算成本'
			when ByTrans.FeeType = 'Percent'
			then N'固定按金额的' + RTrim(Convert(char,Convert(decimal(15,2),100*ByTrans.FeeValue))) + N'%计算成本' End)
	when ByTrans.RefMinAmt = 0 and ByTrans.RefMaxAmt <> @MAX
	then (case when ByTrans.FeeType = 'Fixed' 
			then N'每笔交易额在' + RTrim(Convert(char,Convert(Decimal(15,2),ByTrans.RefMaxAmt/100))) + N'元以下的按每笔' + RTrim(Convert(char,Convert(Decimal(15,2),ByTrans.FeeValue/100))) + N'元计算成本'
			when ByTrans.FeeType = 'Percent'
			then N'每笔交易额在' + RTrim(Convert(char,Convert(Decimal(15,2),ByTrans.RefMaxAmt/100))) + N'元以下的按交易金额的' + RTrim(Convert(char,Convert(Decimal(15,2),100*ByTrans.FeeValue))) + N'%计算成本' End)
	when ByTrans.RefMinAmt <> 0 and ByTrans.RefMaxAmt = @MAX
	then (case when ByTrans.FeeType = 'Fixed' 
			then N'每笔交易额在' + RTrim(Convert(char,Convert(Decimal(15,2),ByTrans.RefMinAmt/100))) + N'元以上的按每笔' + RTrim(Convert(char,Convert(Decimal,ByTrans.FeeValue/100))) + N'元计算成本'
			when ByTrans.FeeType = 'Percent'
			then N'每笔交易额在' + RTrim(Convert(char,Convert(Decimal(15,2),ByTrans.RefMinAmt/100))) + N'元以上的按交易金额的' + RTrim(Convert(char,Convert(Decimal(15,2),100*ByTrans.FeeValue))) + N'%计算成本' End)
	else (case when ByTrans.FeeType = 'Fixed'
			then N'每笔交易额在'+ RTrim(Convert(char,Convert(Decimal(15,2),ByTrans.RefMinAmt/100))) + N'元至' + RTrim(Convert(char,Convert(Decimal(15,2),ByTrans.RefMaxAmt/100))) + N'元，按每笔' + RTrim(Convert(char,Convert(Decimal(15,2),ByTrans.FeeValue/100))) + N'元计算成本'
			when ByTrans.FeeType = 'Percent'
			then N'每笔交易额在'+ RTrim(Convert(char,Convert(Decimal(15,2),ByTrans.RefMinAmt/100))) + N'元至' + RTrim(Convert(char,Convert(Decimal(15,2),ByTrans.RefMaxAmt/100))) + N'元，按交易金额的' + RTrim(Convert(char,Convert(Decimal(15,2),100*ByTrans.FeeValue))) + N'%计算成本' End)
	End as GateDescrip
into
	#ByTransData
from 
	Table_CostRuleByTrans ByTrans;

--2.2 By Year
select
	ByYear.GateNo,
	ByYear.ApplyDate,
	case when ByYear.RefMinAmt = 0 and ByYear.RefMaxAmt = @MAX
	then (case when ByYear.FeeType = 'Fixed' 
			then (case when ByYear.GateGroup <> 0 
				then N'与' + RTRIM(ISNULL((select Top 1 GateNo from Table_CostRuleByYear where GateGroup = ByYear.GateGroup and GateNo <> ByYear.GateNo),N'其他')) + N'等共同包年年费为' +  RTrim(Convert(char,Convert(Decimal(15,0),ByYear.FeeValue/1000000))) + N'万元'
			  when ByYear.GateGroup = 0
				then N'包年年费为' +  RTrim(Convert(char,Convert(Decimal(15,0),ByYear.FeeValue/1000000))) + N'万元' end)
			when ByYear.FeeType = 'Split'
			then N'分润，分润比为' +  RTrim(Convert(char,Convert(Decimal(15,0),ByYear.FeeValue*100))) + N'%' End)
	when ByYear.RefMinAmt = 0 and ByYear.RefMaxAmt <> @MAX
	then (case when ByYear.FeeType = 'Fixed' 
			then N'年交易量在' + RTrim(Convert(char,Convert(Decimal(15,0),ByYear.RefMaxAmt/1000000))) + N'万元以下的年费为' + RTrim(Convert(char,Convert(Decimal(15,0),ByYear.FeeValue/1000000))) + N'万元'
			when ByYear.FeeType = 'Split'
			then N'年交易量在' + RTrim(Convert(char,Convert(Decimal(15,0),ByYear.RefMaxAmt/1000000))) + N'万元以下的按分润，分润比为' +  RTrim(Convert(char,Convert(Decimal(15,0),ByYear.FeeValue*100))) + N'%' End)
	when ByYear.RefMinAmt <> 0 and ByYear.RefMaxAmt = @MAX
	then (case when ByYear.FeeType = 'Fixed' 
			then N'年交易量在' + RTrim(Convert(char,Convert(Decimal(15,0),ByYear.RefMinAmt/1000000))) + N'万元以上的年费为' + RTrim(Convert(char,Convert(Decimal(15,0),ByYear.FeeValue/1000000))) + N'万元'
			when ByYear.FeeType = 'Split'
			then N'年交易量在' + RTrim(Convert(char,Convert(Decimal(15,0),ByYear.RefMinAmt/1000000))) + N'万元以上的按分润，分润比为' +  RTrim(Convert(char,Convert(Decimal(15,0),ByYear.FeeValue*100))) + N'%' End)
	else (case when ByYear.FeeType = 'Fixed'
			then N'年交易量在'+ RTrim(Convert(char,Convert(Decimal(15,0),ByYear.RefMinAmt/1000000))) + N'万元至' + RTrim(Convert(char,Convert(Decimal(15,0),ByYear.RefMaxAmt/1000000))) + N'万元，年费为' + RTrim(Convert(char,Convert(Decimal(15,0),ByYear.FeeValue/1000000))) + N'万元'
			when ByYear.FeeType = 'Percent'
			then N'年交易量在'+ RTrim(Convert(char,Convert(Decimal(15,0),ByYear.RefMinAmt/1000000))) + N'万元至' + RTrim(Convert(char,Convert(Decimal(15,0),ByYear.RefMaxAmt/1000000))) + N'万元，按' + RTrim(Convert(char,Convert(Decimal(15,0),ByYear.FeeValue*100))) + N'%计算成本' End)
	End as GateDescrip
into
	#ByYearData
from 
	Table_CostRuleByYear ByYear;
	
--2.3 By Merchant
select 
	ByMer.GateNo,
	ByMer.ApplyDate,
	case when ByMer.FeeType = 'Fixed' 
	then N'该网关号下商户号为' + Rtrim(ByMer.MerchantNo) + N'的商户固定按每笔'+ RTrim(Convert(char,Convert(Decimal(15,2),ByMer.FeeValue/100))) + N'元计算成本'
	when ByMer.FeeType = 'Percent'
	then N'该网关号下商户号为' + Rtrim(ByMer.MerchantNo) + N'的商户固定按交易金额的'+ RTrim(Convert(char,Convert(Decimal(15,2),100*ByMer.FeeValue))) + N'%计算成本'
	End as GateDescrip
into
	#ByMerchantData
from 
	Table_CostRuleByMer ByMer;
	
--3. Join All
--3.1 Join
select * into #TempData from #ByTransData
union all
select * from #ByYearData
union all
select * from #ByMerchantData;
	
--3.2 All
SELECT  
	B.GateNo,
	B.ApplyDate,
	LEFT(UserList,LEN(UserList)-1) as GateDescrip 
into
	#Temp
FROM (  
		SELECT GateNo,
			   ApplyDate,
			   (SELECT 
					GateDescrip+'；' 
				FROM 
					#TempData 
				WHERE 
					GateNo=A.GateNo
					and
					ApplyDate=A.ApplyDate 
				ORDER BY 
					GateNo FOR XML PATH('')
				) AS UserList  
		FROM 
			#TempData A   
		GROUP BY 
			GateNo,ApplyDate  
)B;
select 
	GateNo,
	MAX(ApplyDate) ApplyDate
into
	#DateNewRule
from 
	Table_GateCostRule
group by
	GateNo;
select
	Temp.*
into
	#Temp2
from
	#DateNewRule DateNew
	inner join
	#Temp Temp
	on
		Temp.GateNo = DateNew.GateNo
		and
		Temp.ApplyDate = DateNew.ApplyDate;
select
	--Temp.GateNo as [网关号],
	--Gate.GateDesc as '网关名称',
	--Convert(char,Temp.ApplyDate,102) as '开始生效日期',
	--Temp.GateDescrip as '成本计算规则'
	Gate.GateNo as GateNo,
	Gate.GateDesc as GateName,
	Convert(char,Temp2.ApplyDate,102) as ApplyDate,
	Temp2.GateDescrip as CostCalculateRule
from
	Table_GateRoute Gate
	left join
	#Temp2 Temp2
	on
		Gate.GateNo = Temp2.GateNo;

--4.Drop Table
drop table #ByTransData;
drop table #ByYearData;
drop table #ByMerchantData;
drop table #TempData;
drop table #Temp;
drop table #DateNewRule;
drop table #Temp2;

end