SELECT TOP 1001 
	CONVERT(VARCHAR,tbl1.shh_date01,120)  AS fld38  ,
	tbl1.shh_char05 AS fld41,
	tbl1.shh_char01 AS fld29,
	tbl1.shh_refid02 AS fld35,
	tbl5.shanghleix_name AS fld218,
	tbl1.shh_int04 AS fld42,
	(select enum_value from tc_enum_str where org_id = 1 and attr_name = 'shh.qingszhouq' and enum_key = tbl1.shh_int04 and lang_id=2) 清算周期,
	tbl1.shh_char06 AS fld43, 
	CONVERT(VARCHAR,tbl1.shh_date02,120)  AS fld39  ,
	tbl1.shh_char02 AS fld30, 
	CONVERT(VARCHAR,tbl1.shh_date03,120)  AS fld40  ,
	tbl1.shh_char04 AS fld36,
	tbl1.shh_int03 AS fld37,
	tbl1.shh_char03 AS fld31,
	tbl1.shh_refid01 AS fld33,
	tbl1.shh_multi02 AS fld44,
	tbl1.stop_flag AS fld28,
	tbl1.owner_user_id AS fld7,
	tbl1.shh_name AS fld8,
	tbl1.shh_id AS fld5,
	tbl1.dept_id AS fld4,
	tbl1.account_id AS fld1,
	tbl3.account_name AS fld86 
FROM 
	tcu_shh tbl1 
	INNER  JOIN 
	tc_account tbl3 
	ON 
		tbl1.org_id=tbl3.org_id 
		AND 
		tbl1.account_id=tbl3.account_id 
	INNER  JOIN 
	tcu_shanghleix tbl5 
	ON 
		tbl1.org_id=tbl5.org_id 
		AND 
		tbl1.shh_refid02=tbl5.shanghleix_id 
WHERE 
	(tbl1.org_id=1) 
	AND 
	(tbl1.shh_id<>0) 
	AND 
	(tbl3.is_deleted=0)
	and
	tbl1.shh_name = '808080231800257'
ORDER BY  
	tbl1.shh_id DESC	
	
	
select
	d.shh_id,
	m.account_id,
	m.acct_int04,
	(select enum_value from tc_enum_str where org_id = 1 and attr_name = 'Account.guiss' and enum_key = m.acct_int04 and lang_id=2) 省,
	m.acct_int05,
	(select enum_value from tc_enum_str where org_id = 1 and attr_name = 'Account.guischengs' and enum_key = m.acct_int05 and lang_id=2) 城市,
	d.shh_name 商户号,
	qy.enum_value 销售区域,
	lx.shanghleix_name 商户类型,
	m.account_name 商户名称,
	e.enum_value 所属行业,
	q.enum_value 渠道,
	qf.enum_value 渠道分公司,
	u.user_name 所属客户经理,
	dep.dept_name 负责部门,
	d.shh_date02 签单时间,
	dj.enum_value 商户等级,
	c.currency_name,
	c.exchange_ratio 汇率
from 
	tcu_shh d --商户号表
	join 
	tc_account m 
	on 
		d.account_id=m.account_id --关联商户（客户）表
	left join 
	tcu_shanghleix lx 
	on 
		d.shh_refid02=lx.shanghleix_id --关联商户类型表
	left join 
	tc_user u 
	on 
		d.owner_user_id=u.user_id --关联员工用户表
	left join 
	tc_department dep 
	on 
		d.dept_id=dep.dept_id --关联组织部门表
	left join 
	(select * from tc_currency where currency_id>0 and org_id=1) c 
	on 
		d.shh_refid01=c.currency_id --关联币种汇率表
	left join 
	(select * from tc_enum_str where attr_name='Account.Industry' and org_id=1 and lang_id=2) e 
	on 
		e.enum_key=m.account_industry --获取行业的枚举值
	left join 
	(select * from tc_enum_str where attr_name='Account.qud' and org_id=1 and lang_id=2) q 
	on 
		q.enum_key=d.shh_int01 --获取渠道的枚举值
	left join 
	(select * from tc_enum_str where attr_name='Account.qudfengs' and org_id=1 and lang_id=2) qf 
	on 
		qf.enum_key=d.shh_int02 --获取渠道分公司的枚举值
	left join 
	(select * from tc_enum_str where attr_name='Account.ssarea' and org_id=1 and lang_id=2) qy 
	on 
		qy.enum_key=m.acct_int07 --获取销售区域的枚举值
	left join 
	(select * from tc_enum_str where attr_name='Account.MerchantClass' and org_id=1 and lang_id=2) dj 
	on 
		dj.enum_key=m.acct_int06 --获取商户等级
where 
	d.org_id=1  
	and 
	d.shh_id>0 
	and 
	u.org_id=1 
	and 
	dep.org_id=1
	and
	d.shh_name = '808080211300105'
	
select * from tc_enum_str where enum_value like '%T+1%'


SELECT   
	CONVERT(VARCHAR,tbl1.shh_date01,120)  AS fld38  ,
	tbl1.shh_int09 AS fld49,
	tbl1.shh_int08 AS fld48,
	tbl1.shh_int06 AS fld46,
	tbl1.shh_char05 AS fld41,
	tbl1.shh_char01 AS fld29,
	tbl1.shh_multi03 AS fld50,
	tbl1.shh_int05 AS fld45,
	tbl1.shh_refid02 AS fld35,
	tbl5.shanghleix_name AS fld218,
	tbl1.shh_int02 AS fld52,
	tbl1.shh_int01 AS fld51,
	tbl1.shh_int04 AS fld42,
	tbl1.shh_char06 AS fld43, 
	CONVERT(VARCHAR,tbl1.shh_date02,120)  AS fld39  ,
	tbl1.shh_char02 AS fld30, 
	CONVERT(VARCHAR,tbl1.shh_date03,120)  AS fld40  ,
	tbl1.shh_char07 AS fld53,
	tbl1.shh_char04 AS fld36,
	tbl1.shh_int03 AS fld37,
	tbl1.shh_int07 AS fld47,
	tbl1.shh_char03 AS fld31,
	tbl1.shh_refid01 AS fld33,
	--tbl4.currency_id AS fld206,
	--tbl4.exchange_ratio AS fld210,
	tbl1.shh_multi02 AS fld44,
	tbl1.stop_flag AS fld28,
	tbl1.privilege_02 AS fld13,
	tbl1.privilege_01 AS fld12,
	tbl1.owner_user_id AS fld7,
	tbl1.shh_name AS fld8, 
	CONVERT(VARCHAR,tbl1.modify_time,120)  AS fld24  ,
	tbl1.modify_user_id AS fld6,
	tbl1.close_flag AS fld27,
	tbl1.identify_code AS fld20,
	tbl1.shh_id AS fld5,
	tbl1.expense AS fld17,
	tbl1.dept_id AS fld4
	--, 
	--CONVERT(VARCHAR,tbl1.create_time,120)  AS fld22  ,
	--tbl1.create_user_id AS fld3, 
	--CONVERT(VARCHAR,tbl1.close_time,120)  AS fld26  ,
	--tbl1.close_user_id AS fld2,
	--tbl1.approved_expense AS fld18,
	--tbl1.account_id AS fld1,
	--tbl3.account_name AS fld86 
FROM 
	tcu_shh tbl1 
	--INNER  JOIN 
	--tc_account tbl3 
	--ON 
	--	tbl1.org_id=tbl3.org_id 
	--	AND 
	--	tbl1.account_id=tbl3.account_id 
	--INNER  JOIN 
	--tc_currency tbl4 
	--ON
	--	tbl1.org_id=tbl4.org_id 
	--	AND 
	--	tbl1.shh_refid01=tbl4.currency_id 
	INNER  JOIN 
	tcu_shanghleix tbl5 
	ON 
		tbl1.org_id=tbl5.org_id 
		AND 
		tbl1.shh_refid02=tbl5.shanghleix_id 
WHERE 
	(tbl1.org_id=1) 
	AND 
	(tbl1.shh_id<>0) 
	--AND 
	--(tbl3.is_deleted=0) 
	AND 
	(tbl1.shh_id=185) 
ORDER BY  
	tbl1.shh_id DESC

SELECT   
	CONVERT(VARCHAR(10),tbl1.acct_date03,120)  AS fld109  ,
	tbl1.acct_char08 AS fld108,
	tbl1.acct_char01 AS fld99,
	tbl1.acct_int08 AS fld98,
	tbl1_attr.acct_char15 AS fld128, 
	CONVERT(VARCHAR(10),tbl1.acct_date02,120)  AS fld107  ,
	tbl1.acct_int11 AS fld118, 
	CONVERT(VARCHAR(10),tbl1.acct_date01,120)  AS fld105  ,
	tbl1.acct_int09 AS fld103,
	tbl1.acct_char06 AS fld104,
	tbl1.acct_char04 AS fld83,
	tbl1.acct_int03 AS fld89,
	tbl1.acct_char07 AS fld106,
	tbl1.acct_int15 AS fld129,
	tbl1_attr.acct_char16 AS fld131,
	tbl1_attr.acct_char13 AS fld114,
	tbl1_attr.acct_refid03 AS fld116,
	tbl5.prod_name AS fld440,
	tbl1_attr.acct_char14 AS fld124,
	tbl1.acct_int07 AS fld93,
	tbl1.acct_char11 AS fld95, 
	CONVERT(VARCHAR(10),tbl1.acct_date04,120)  AS fld111  ,
	tbl1.acct_char09 AS fld110,
	tbl1.acct_int17 AS fld135,
	tbl1.acct_int18 AS fld136,
	tbl1.acct_refid02 AS fld102,
	tbl3.account_name AS fld170,
	tbl1.acct_refid01 AS fld94,
	tbl4.account_name AS fld307,
	tbl1.acct_char02 AS fld100,
	tbl1.acct_int10 AS fld113,
	tbl1.acct_int02 AS fld117,
	tbl1.acct_multi02 AS fld86,
	tbl1.acct_int12 AS fld123,
	tbl1.acct_int14 AS fld127,
	tbl1.acct_int13 AS fld126,
	tbl1.acct_int16 AS fld130, 
	CONVERT(VARCHAR(10),tbl1.acct_date05,120)  AS fld132  ,
	tbl1.acct_int01 AS fld88,
	tbl1.acct_dec03 AS fld121,
	tbl1.acct_dec02 AS fld120,
	tbl1.acct_dec01 AS fld119,
	tbl1.acct_dec04 AS fld122,
	tbl1.acct_int19 AS fld137,
	tbl1.acct_char12 AS fld87,
	tbl1.acct_char05 AS fld84, 
	CONVERT(VARCHAR(10),tbl1.acct_date06,120)  AS fld133  , 
	CONVERT(VARCHAR(10),tbl1.acct_date07,120)  AS fld134  ,
	tbl1.acct_int04 AS fld90,
	tbl1.acct_int05 AS fld91,
	tbl1.acct_multi01 AS fld85,
	tbl1.acct_char10 AS fld112,
	tbl1.acct_char03 AS fld101,
	tbl1.acct_multi03 AS fld125,
	tbl1.account_website AS fld40,
	tbl1.valid_scores AS fld77,
	tbl1.account_type AS fld13, 
	CONVERT(VARCHAR,tbl1.touch_time,120)  AS fld44  ,
	tbl1.ticker_symbol AS fld43,
	tbl1.stop_flag AS fld17,
	tbl1.src_type AS fld12,
	tbl23_lang_1.data_value AS fld1410,
	tbl1.src_id AS fld16,
	tbl1.account_simple_code AS fld19,
	tbl1.shipping_zipcode AS fld64,
	tbl1.shipping_street AS fld60,
	tbl1.shipping_state AS fld62,
	tbl1.shipping_country AS fld63,
	tbl1.shipping_city AS fld61,
	tbl1.shipping_address AS fld65,
	tbl1.shareable AS fld81,
	tbl1.sic_code AS fld41, 
	CONVERT(VARCHAR,tbl1.recently_quote_time,120)  AS fld67  , 
	CONVERT(VARCHAR,tbl1.recently_invoice_time,120)  AS fld66  , 
	CONVERT(VARCHAR,tbl1.recently_contract_time,120)  AS fld70  , 
	CONVERT(VARCHAR,tbl1.recently_chance_time,120)  AS fld69  , 
	CONVERT(VARCHAR,tbl1.recently_activity_time,120)  AS fld68  ,
	tbl1.received_amount AS fld52,
	tbl1.receivable_amount AS fld49,
	tbl1.privilege_02 AS fld25,
	tbl1.privilege_01 AS fld24,
	tbl1.pre_amount AS fld48,
	tbl1.account_phone AS fld35,
	tbl1.parent_account_id AS fld8,
	tbl22.account_name AS fld1294,
	tbl1.owner_user_id AS fld7,
	tbl1.ou_id AS fld82,
	tbl1.account_name AS fld18, 
	CONVERT(VARCHAR,tbl1.modify_time,120)  AS fld74  ,
	tbl1.modify_user_id AS fld6,
	tbl1.account_mobile_phone AS fld34,
	tbl1.acct_int06 AS fld92, 
	CONVERT(VARCHAR(10),tbl1.invalid_scores_time,120)  AS fld80  ,
	tbl1.invalid_scores AS fld79,
	tbl1.initreceivable_amount AS fld47,
	tbl1.initpre_amount AS fld46,
	tbl1.account_industry AS fld30,
	tbl1.identify_code AS fld55,
	tbl1.account_id AS fld5,
	tbl1.account_fax AS fld36,
	tbl1.expense AS fld37,
	tbl1.account_employees AS fld33,
	tbl1.account_email AS fld39,
	tbl1.dept_id AS fld2,
	tbl1.d_source AS fld14,
	tbl1.credit_day AS fld45,
	tbl1.credit_amount AS fld51, 
	CONVERT(VARCHAR,tbl1.create_time,120)  AS fld72  ,
	tbl1.create_user_id AS fld1,
	tbl1.account_card_type AS fld32,
	tbl1.account_card_no AS fld42,
	tbl1.billing_zipcode AS fld58,
	tbl1.billing_street AS fld53,
	tbl1.billing_state AS fld56,
	tbl1.billing_country AS fld57,
	tbl1.billing_city AS fld54,
	tbl1.billing_address AS fld59,
	tbl1.approved_expense AS fld38,
	tbl1.annual_revenue AS fld31,
	tbl1.accumulated_scores AS fld78,
	tbl1.account_number AS fld15,
	tbl1.account_balance AS fld50 
FROM 
	tc_account tbl1 
	INNER  JOIN 
	tc_account_attr tbl1_attr 
	ON 
		tbl1.org_id=tbl1_attr.org_id 
		AND 
		tbl1.account_id=tbl1_attr.account_id 
	INNER  JOIN 
	tc_account tbl3 
	ON 
		tbl1.org_id=tbl3.org_id 
		AND 
		tbl1.acct_refid02=tbl3.account_id 
	INNER  JOIN 
	tc_account tbl4 
	ON 
		tbl1.org_id=tbl4.org_id 
		AND 
		tbl1.acct_refid01=tbl4.account_id 
	INNER  JOIN 
	tc_product tbl5 
	ON 
		tbl1_attr.org_id=tbl5.org_id 
		AND 
		tbl1_attr.acct_refid03=tbl5.prod_id 
	INNER  JOIN 
	tc_account tbl22 
	ON 
		tbl1.org_id=tbl22.org_id 
		AND 
		tbl1.parent_account_id=tbl22.account_id 
	INNER  JOIN 
	tc_data_object tbl23 
	ON 
		tbl1.org_id=tbl23.org_id 
		AND 
		tbl1.src_id=tbl23.obj_id 
		AND 
		tbl1.src_type=tbl23.obj_type 
	INNER  JOIN 
	tc_data_object_lang tbl23_lang_1 
	ON 
		tbl23.org_id=tbl23_lang_1.org_id 
		AND 
		tbl23.obj_id=tbl23_lang_1.obj_id 
		AND 
		tbl23.obj_type=tbl23_lang_1.obj_type 
WHERE 
	(tbl1.org_id=1) 
	AND 
	(tbl23_lang_1.lang_id=2) 
	AND 
	(tbl1.account_id<>0) 
	AND 
	(tbl1.is_deleted=0) 
	AND 
	(tbl3.is_deleted=0) 
	AND 
	(tbl4.is_deleted=0) 
	AND 
	(tbl5.is_deleted=0) 
	AND 
	(tbl1.account_id=99767) 
ORDER BY  
	tbl1.account_id DESC
	
select * from tc_account where account_id = 99767
select
	a.acct_char11,
	b.account_name
from
	tc_account a
	inner join
	tc_account b
	on
		a.acct_refid02 = b.account_id
where
	a.org_id = 1
	and
	a.acct_char11 <> b.account_name;
	




select o.obj_name 对象名,so.label 对象中文名,o.attr_name 属性名,s.label 属性中文名,o.tbl_name 表名,o.fld_name 字段
 from dd_dict_str s,dd_attribute o,(SELECT *  FROM [dd_dict_str]
  where org_id=1 and lang_id=2 and dict_name not like '%.%') so
 where s.org_id=1 and o.org_id=1 and o.attr_name=s.dict_name and s.lang_id=2
 and o.obj_name=so.dict_name 
and s.label like N'%商户号%' 
 and so.label like N'%登记%'
 order by o.tbl_name, o.fld_name
 
 select o.obj_name 对象名,so.label 对象中文名,o.attr_name 属性名,s.label 属性中文名,o.tbl_name 表名,o.fld_name 字段
 from dd_dict_str s,dd_attribute o,(SELECT *  FROM [dd_dict_str]
  where org_id=1 and lang_id=2 and dict_name not like '%.%') so
 where s.org_id=1 and o.org_id=1 and o.attr_name=s.dict_name and s.lang_id=2
 and o.obj_name=so.dict_name 
and s.label like N'%分润%' 
 and so.label like N'%登记%'
 order by o.tbl_name, o.fld_name
 
-------------------------------------------------------

--代收付网关登记表
select * from tcu_dsfwg
select * from tcu_dsfwg_1_1
select * from tcu_dsfwg_attr

--网关登记表
select * from tcu_wanggdengjb
select * from tcu_wanggdengjb_1_1
select * from tcu_wanggdengjb_1_2
select * from tcu_wanggdengjb_1_3
select * from tcu_wanggdengjb_attr
select * from tcu_wanggdengjb_xattr

select
	a.wanggdengjb_refid01 [商户号ID],
	c.char_10 [银联手机支付商户号],
	c.char_11 CP商户号,
	d.char_50 EBPP商户号,
	d.char_60 集团商户号,
	b.wanggdengjb_char13 银商账单支付商户号,
	--a.wanggdengjb_int09,
	a.wanggdengjb_int11,
	--b.wanggdengjb_int29,
	--b.wanggdengjb_int42,
	a.wanggdengjb_int13,
	a.*
from
	tcu_wanggdengjb a
	inner join
	tcu_wanggdengjb_attr b
	on
		a.wanggdengjb_id = b.wanggdengjb_id
	inner join
	tcu_wanggdengjb_1_1 c
	on
		a.wanggdengjb_id = c.wanggdengjb_id
	inner join
	tcu_wanggdengjb_1_2 d
	on
		a.wanggdengjb_id = d.wanggdengjb_id
where
	a.org_id = 1
	and
	(
		--a.wanggdengjb_int09 = 1001
		--or
		a.wanggdengjb_int11 = 1001
		--or
		--b.wanggdengjb_int29 = 1001
		--or
		--b.wanggdengjb_int42 = 1001
	)
	and
	a.wanggdengjb_name like N'杭州顶津食品有限公司上海分公司%'

select * from tcu_shh where shh_id = 237
select * from tc_account where account_id = 2142341

select 
	* 
from 
	tc_enum_str 
where 
	attr_name in ('wanggdengjb.shouzliangx',
					'wanggdengjb.shouzliangx2',
					'wanggdengjb.istwowire',
					'wanggdengjb.isszlianxian',
					'wanggdengjb.tktsxf')
	and
	lang_id = 2 and org_id = 1 
 






