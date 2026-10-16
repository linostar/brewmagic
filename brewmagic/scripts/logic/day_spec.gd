class_name DaySpec
extends Resource
## One story day from data/days.json (fields as in data/SCHEMA.md). Built by Content.

var id := ""
var day := 1
var title := ""
var morning_note := ""
var patience_scale := 1.0
## Day 1 only (0 on other days).
var starting_coins := 0
## Day 1 only: ingredient id -> count; absent ids mean 0.
var starting_stock: Dictionary[String, int] = {}
## Days >= 2 only: ingredient id -> price, for every ingredient unlocked by this day.
var market: Dictionary[String, int] = {}
## In arrival order.
var customers: Array[DayCustomer] = []
