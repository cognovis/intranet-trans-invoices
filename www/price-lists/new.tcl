# /packages/intranet-trans-invoices/www/price-lists/new.tcl
#
# Copyright (C) 2003-2004 Project/Open
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    Create or edit an entry in the price list
    @param form_mode edit or display
    @author frank.bergmann@project-open.com
} {
    price_id:integer,optional
    customer_id:integer
    {return_url "/intranet/customers/"}
    { currency "" }
    edit_p:optional
    message:optional
    { form_mode "edit" }
}


# ------------------------------------------------------------------
# Default & Security
# ------------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
set user_is_admin_p [im_is_user_site_wide_or_intranet_admin $user_id]
if {!$user_is_admin_p} {
    ad_return_complaint 1 "You have insufficient privileges to use this page"
    return
}

set action_url "new"
set focus "price.var_name"
set page_title "New Price"
set context [ad_context_bar $page_title]


if {"" == $currency} {
    set currency [ad_parameter -package_id [im_package_cost_id] "DefaultCurrency" "" "EUR"]
}

# ------------------------------------------------------------------
# Build the form
# ------------------------------------------------------------------

set uom_options [db_list_of_lists uom_options "
select category, category_id
from im_categories
where category_type = 'Intranet UoM'
"]

set task_type_options [db_list_of_lists uom_options "
select category, category_id
from im_categories
where category_type = 'Intranet Project Type'
"]
set task_type_options [linsert $task_type_options 0 [list "" ""]]

set language_options [db_list_of_lists uom_options "
select category, category_id
from im_categories
where category_type = 'Intranet Translation Language'
"]
set language_options [linsert $language_options 0 [list "" ""]]

set subject_area_options [db_list_of_lists uom_options "
select category, category_id
from im_categories
where category_type = 'Intranet Translation Subject Area'
"]
set subject_area_options [linsert $subject_area_options 0 [list "" ""]]

set include_empty 0
set currency_options [im_currency_options $include_empty]

ad_form \
    -name price \
    -cancel_url $return_url \
    -action $action_url \
    -mode $form_mode \
    -export {next_url user_id return_url} \
    -form {
	price_id:key(im_trans_prices_seq)
	{customer_id:text(hidden)}
	{uom_id:text(select) {label "Unit of Measure"} {options $uom_options} }
	{task_type_id:text(select),optional {label "Task Type"} {options $task_type_options} }
	{source_language_id:text(select),optional {label "Source Language"} {options $language_options} }
	{target_language_id:text(select),optional {label "Target Language"} {options $language_options} }
	{subject_area_id:text(select),optional {label "Subject Area"} {options $subject_area_options} }
	{amount:text(text) {label "Amount"} {html {size 10}}}
	{currency:text(select) {label "Currency"} {options $currency_options} }
    }


ad_form -extend -name price -on_request {
    # Populate elements from local variables

} -select_query {

	select	p.*
	from	im_trans_prices p
	where	p.price_id = :price_id

} -new_data {

    db_dml price_insert "
insert into im_trans_prices (
	price_id,
	uom_id,
	customer_id,
	task_type_id,
	target_language_id,
	source_language_id,
	subject_area_id,
	currency,
	price
) values (
	:price_id,
	:uom_id,
	:customer_id,
	:task_type_id,
	:target_language_id,
	:source_language_id,
	:subject_area_id,
	:currency,
	:amount
)"

} -edit_data {

    db_dml price_update "
	update im_prices set
	        package_name    = :package_name,
	        label           = :label,
	        name            = :name,
	        url             = :url,
	        sort_order      = :sort_order,
	        parent_price_id  = :parent_price_id
	where
		price_id = :price_id
"
} -on_submit {

	ns_log Notice "new1: on_submit"


} -after_submit {

	ad_returnredirect $return_url
	ad_script_abort
}