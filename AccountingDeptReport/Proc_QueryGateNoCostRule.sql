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
			then N'�̶���ÿ��' + RTrim(Convert(char,Convert(Decimal(15,2),ByTrans.FeeValue/100))) + N'Ԫ����ɱ�'
			when ByTrans.FeeType = 'Percent'
			then N'�̶�������' + RTrim(Convert(char,Convert(decimal(15,2),100*ByTrans.FeeValue))) + N'%����ɱ�' End)
	when ByTrans.RefMinAmt = 0 and ByTrans.RefMaxAmt <> @MAX
	then (case when ByTrans.FeeType = 'Fixed' 
			then N'ÿ�ʽ��׶���' + RTrim(Convert(char,Convert(Decimal(15,2),ByTrans.RefMaxAmt/100))) + N'Ԫ���µİ�ÿ��' + RTrim(Convert(char,Convert(Decimal(15,2),ByTrans.FeeValue/100))) + N'Ԫ����ɱ�'
			when ByTrans.FeeType = 'Percent'
			then N'ÿ�ʽ��׶���' + RTrim(Convert(char,Convert(Decimal(15,2),ByTrans.RefMaxAmt/100))) + N'Ԫ���µİ����׽���' + RTrim(Convert(char,Convert(Decimal(15,2),100*ByTrans.FeeValue))) + N'%����ɱ�' End)
	when ByTrans.RefMinAmt <> 0 and ByTrans.RefMaxAmt = @MAX
	then (case when ByTrans.FeeType = 'Fixed' 
			then N'ÿ�ʽ��׶���' + RTrim(Convert(char,Convert(Decimal(15,2),ByTrans.RefMinAmt/100))) + N'Ԫ���ϵİ�ÿ��' + RTrim(Convert(char,Convert(Decimal,ByTrans.FeeValue/100))) + N'Ԫ����ɱ�'
			when ByTrans.FeeType = 'Percent'
			then N'ÿ�ʽ��׶���' + RTrim(Convert(char,Convert(Decimal(15,2),ByTrans.RefMinAmt/100))) + N'Ԫ���ϵİ����׽���' + RTrim(Convert(char,Convert(Decimal(15,2),100*ByTrans.FeeValue))) + N'%����ɱ�' End)
	else (case when ByTrans.FeeType = 'Fixed'
			then N'ÿ�ʽ��׶���'+ RTrim(Convert(char,Convert(Decimal(15,2),ByTrans.RefMinAmt/100))) + N'Ԫ��' + RTrim(Convert(char,Convert(Decimal(15,2),ByTrans.RefMaxAmt/100))) + N'Ԫ����ÿ��' + RTrim(Convert(char,Convert(Decimal(15,2),ByTrans.FeeValue/100))) + N'Ԫ����ɱ�'
			when ByTrans.FeeType = 'Percent'
			then N'ÿ�ʽ��׶���'+ RTrim(Convert(char,Convert(Decimal(15,2),ByTrans.RefMinAmt/100))) + N'Ԫ��' + RTrim(Convert(char,Convert(Decimal(15,2),ByTrans.RefMaxAmt/100))) + N'Ԫ�������׽���' + RTrim(Convert(char,Convert(Decimal(15,2),100*ByTrans.FeeValue))) + N'%����ɱ�' End)
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
				then N'��' + RTRIM(ISNULL((select Top 1 GateNo from Table_CostRuleByYear where GateGroup = ByYear.GateGroup and GateNo <> ByYear.GateNo),N'����')) + N'�ȹ�ͬ�������Ϊ' +  RTrim(Convert(char,Convert(Decimal(15,0),ByYear.FeeValue/1000000))) + N'��Ԫ'
			  when ByYear.GateGroup = 0
				then N'�������Ϊ' +  RTrim(Convert(char,Convert(Decimal(15,0),ByYear.FeeValue/1000000))) + N'��Ԫ' end)
			when ByYear.FeeType = 'Split'
			then N'���󣬳ɱ�����Ϊ0' End)
	when ByYear.RefMinAmt = 0 and ByYear.RefMaxAmt <> @MAX
	then (case when ByYear.FeeType = 'Fixed' 
			then N'�꽻������' + RTrim(Convert(char,Convert(Decimal(15,0),ByYear.RefMaxAmt/1000000))) + N'��Ԫ���µ����Ϊ' + RTrim(Convert(char,Convert(Decimal(15,0),ByYear.FeeValue/1000000))) + N'��Ԫ'
			when ByYear.FeeType = 'Split'
			then N'�꽻������' + RTrim(Convert(char,Convert(Decimal(15,0),ByYear.RefMaxAmt/1000000))) + N'��Ԫ���µİ�����Ʒѣ��ɱ�����Ϊ0' End)
	when ByYear.RefMinAmt <> 0 and ByYear.RefMaxAmt = @MAX
	then (case when ByYear.FeeType = 'Fixed' 
			then N'�꽻������' + RTrim(Convert(char,Convert(Decimal(15,0),ByYear.RefMinAmt/1000000))) + N'��Ԫ���ϵ����Ϊ' + RTrim(Convert(char,Convert(Decimal(15,0),ByYear.FeeValue/1000000))) + N'��Ԫ'
			when ByYear.FeeType = 'Split'
			then N'�꽻������' + RTrim(Convert(char,Convert(Decimal(15,0),ByYear.RefMinAmt/1000000))) + N'��Ԫ���ϵİ�����Ʒѣ��ɱ�����Ϊ0' End)
	else (case when ByYear.FeeType = 'Fixed'
			then N'�꽻������'+ RTrim(Convert(char,Convert(Decimal(15,0),ByYear.RefMinAmt/1000000))) + N'��Ԫ��' + RTrim(Convert(char,Convert(Decimal(15,0),ByYear.RefMaxAmt/1000000))) + N'��Ԫ�����Ϊ' + RTrim(Convert(char,Convert(Decimal(15,0),ByYear.FeeValue/1000000))) + N'��Ԫ'
			when ByYear.FeeType = 'Percent'
			then N'�꽻������'+ RTrim(Convert(char,Convert(Decimal(15,0),ByYear.RefMinAmt/1000000))) + N'��Ԫ��' + RTrim(Convert(char,Convert(Decimal(15,0),ByYear.RefMaxAmt/1000000))) + N'��Ԫ����' + RTrim(Convert(char,Convert(Decimal(15,0),ByYear.FeeValue*100))) + N'%����ɱ�' End)
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
	then N'�����غ����̻���Ϊ' + Rtrim(ByMer.MerchantNo) + N'���̻��̶���ÿ��'+ RTrim(Convert(char,Convert(Decimal(15,2),ByMer.FeeValue/100))) + N'Ԫ����ɱ�'
	when ByMer.FeeType = 'Percent'
	then N'�����غ����̻���Ϊ' + Rtrim(ByMer.MerchantNo) + N'���̻��̶������׽���'+ RTrim(Convert(char,Convert(Decimal(15,2),100*ByMer.FeeValue))) + N'%����ɱ�'
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
	GateNo,
	ApplyDate,
	LEFT(UserList,LEN(UserList)-1) as GateDescrip 
into
	#Temp
FROM (  
		SELECT GateNo,
			   ApplyDate,
			   (SELECT 
					GateDescrip+'��' 
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
			GateNo,
			ApplyDate  
)B ;

select
	Gate.GateNo as GateNo,
	Gate.GateDesc as GateName,
	Convert(char,Temp.ApplyDate,102) as ApplyDate,
	Temp.GateDescrip as CostCalculateRule
from
	Table_GateRoute Gate
	left join
	#Temp Temp
	on
		Temp.GateNo = Gate.GateNo;


--4.Drop Table
drop table #ByTransData;
drop table #ByYearData;
drop table #ByMerchantData;
drop table #TempData;
drop table #Temp;

end

