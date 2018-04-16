// graphs using the data from the hdtgm.js file


// surprising that this tooltip position isn't standard!
Chart.Tooltip.positioners.atMouse = function(elements, eventPosition) {
    return eventPosition;
};

var GRAPHCACHE = Array();
var COLOR25 = [ '#00ff80','#33cc80','#669980','#996680','#993300','#ff0000','#cc0033','#990066','#660099','#3300cc','#0000ff','#0033cc','#006699','#009966','#00cc33','#00ff00','#00ff33','#00ff66','#00ff99','#00ffcc','#00ffff','#00cccc','#339999','#665599','#990099' ]; 
var ABVALUE = function(a,b){ return a.value - b.value; };
var BAVALUE = function(a,b){ return b.value - a.value; };

function showGraph(which) { 

	$('#side-menu li').removeClass('active');    // clear active class
	if (which == -1) {
		$('#body-div').show();
		$('canvas').addClass('graph-hide');
	} else {
		var index = which.data.item;

		$(which.target).parent().addClass('active'); // set the target <li> active (parent of the event.target item)

		$('#body-div').hide();
		$('canvas').addClass('graph-hide');
		$('#c-'+GRAPH[index].id).removeClass('graph-hide');
		var ctx = document.getElementById('c-'+GRAPH[index].id).getContext('2d');
		if (! GRAPHCACHE[index])
			GRAPHCACHE[index] = GRAPH[index].prepFn();
		var chart = new Chart(ctx, GRAPHCACHE[index]);
	}
}

var GRAPH = [
	{
		"id" : "live-shows",
		"graphType": "misc-list",
		"title" :  "Number of live and studio shows",
		"prepFn": function() { 
	 		var liveCount = 0, studioCount = 0;
	 		for (var m = 1; m < SHOWS.length; ++m)
	 			if (SHOWS[m] === null)
	 				++studioCount;
	 			else if (SHOWS[m].live == 1)
	 				++liveCount;
	 			else
	 				++studioCount;
			return {
	 			type: 'pie',
	 			data: {
	 				datasets: [{
	 					label: "Number of live shows",
	 					data: [ liveCount, studioCount ],
	 					backgroundColor: [ "rgb(255,0,0)", "rgb(0,0,255)" ],
	 					datalabels: {
	 						anchor: 'center',
 							color: 'white',
	 						font: {
	 							size: '36'
	 						},
	 						formatter: function(value, context) {
    							return value + ' (' + Math.round((value / (liveCount + studioCount)) * 100) + '%)';
							}
	 					}
	 				}],
	 				labels: [
	 					'Live',
	 					'Studio'
	 				]
	 			},
	 			options: {
					title: { display: true, text: "The number of live vs. studio episodes", fontSize: 14 },
	 			}
	 		};
		 },
	},
	{
		"title": "Most frequent genres",
		"id": "movie-genres",
		"graphType": "movies-list",
		"prepFn": function() {
			var tally = Array(), n,this_one;
			for (var iter = 1; iter < SHOWS.length; ++iter) {
				if (SHOWS[iter] && SHOWS[iter].movie && MOVIES[SHOWS[iter].movie].genre_ids) {
					for (n = 0; n < MOVIES[SHOWS[iter].movie].genre_ids.length; ++n) {
						this_one = MOVIES[SHOWS[iter].movie].genre_ids[n];
						tally[this_one] = (isNaN(tally[this_one]) ? 1 : tally[this_one] + 1);
					}
				}
			}
			var sortme = Array();
			for (n = 0; n < GENRES.length; ++n) {
				this_one = GENRES[n];

				if (tally[this_one.id] > 1)
					sortme.push({ 'label': this_one.label, 'value': tally[this_one.id] });
			}
			sortme.sort(BAVALUE);
			var labelArray = Array(), valueArray = Array();
			for (n = 0; n < sortme.length; ++n) {
				labelArray.push(sortme[n].label);
				valueArray.push(sortme[n].value);
			}
			return {
				type: 'bar',
				data: { 
					datasets: [{
						label: 'Most frequent genres',
						"data": valueArray,
						backgroundColor: COLOR25,
						datalabels: {
							display: false
						}
					}],
					labels: labelArray
				},
				options: {
					legend: { display: false }, 
					title: { display: true, text: "Most frequently covered genres", fontSize: 14 },
					scales: {
						yAxes: [{
							ticks: {
								beginAtZero: true
							}
						}]
					}
				}
			};
		}
	},
	{
		"title": "Group by decade",
		"id": "decade-count",
		"graphType": "movies-list",
		"prepFn": function() {
			var sparseColorArray = Array();
			var years = [];
			function initColorArray() {
				for (var i = 1950; i < 2020; i += 10) {
					var baseColor;
					switch (i) {
						case 1950: baseColor = Array(255,204,153); break;
						case 1960: baseColor = Array(224,224,224); break;
						case 1970: baseColor = Array(255,153,153); break;
						case 1980: baseColor = Array(153,204,255); break;
						case 1990: baseColor = Array(255,255,153); break;
						case 2000: baseColor = Array(153,255,255); break;
						case 2010: baseColor = Array(204,153,255); break;
					}
					sparseColorArray[i] = '#' + ('0'+baseColor[0].toString(16)).substr(-2) + ('0'+baseColor[1].toString(16)).substr(-2) + ('0'+baseColor[2].toString(16)).substr(-2);
				}
			}
			initColorArray();
			for (var m = 1; m < SHOWS.length; ++m)
				if (SHOWS[m].movie !== null && MOVIES[SHOWS[m].movie] && /^\d\d\d\d/.test(MOVIES[SHOWS[m].movie].release_date)) {
					var y = /^(\d\d\d)/.exec(MOVIES[SHOWS[m].movie].release_date)[1];
					if (years[y * 10])
						++years[y * 10];
					else 
						years[y * 10] = 1;
				}
			var labelData = Array(),barLabelData = Array(),valueData = Array(), bkgColor = Array();
			for (var iter = 1900; iter < years.length; iter += 10) {
				if (years[iter] > 0) {
					labelData.push(iter+'s');
					barLabelData.push('Number of movies in the '+iter+'s');
					valueData.push(years[iter]);
					bkgColor.push(sparseColorArray[iter]);
				}

			}
			return {
				type: 'bar',
				data: { 
					datasets: [{
						label: 'Movies grouped by decade',
						"data": valueData,
						backgroundColor: bkgColor,
						datalabels: {
							display: false
						}
					}],
					labels: labelData
				},
				options: {
					legend: { display: false }, 
					title: { display: true, text: "Movies grouped by release year", fontSize: 14 },
					tooltips: {
						callbacks: {
							label: function(tooltipItem, data) {
								var thisYear = tooltipItem.xLabel;
								var tlist = [];
								for (var iter = 1; iter < SHOWS.length; ++iter)  {
									try {
										if (SHOWS[iter] && SHOWS[iter].movie && parseInt(MOVIES[SHOWS[iter].movie].release_date) == thisYear) {
											tlist.push(MOVIES[SHOWS[iter].movie].title);
										}
									} catch (error) { console.log('failed at iter = ' + iter); console.error(error); }
								}
								return tlist;
							}
						}
					},
					scales: {
						yAxes: [{
							ticks: {
								beginAtZero: true
							}
						}]
					}
				}
			}; 
		}
	},
	{
		"title": "Group by year",
		"id": "year-count",
		"graphType": "movies-list",
		"prepFn": function() {
			var sparseColorArray = Array();
			var years = [];
			function initColorArray() {
				for (var i = 1950; i < 2020; i += 10) {
					var baseColor;
					switch (i) {
						case 1950: baseColor = Array(255,204,153); break;
						case 1960: baseColor = Array(224,224,224); break;
						case 1970: baseColor = Array(255,153,153); break;
						case 1980: baseColor = Array(153,204,255); break;
						case 1990: baseColor = Array(255,255,153); break;
						case 2000: baseColor = Array(153,255,255); break;
						case 2010: baseColor = Array(204,153,255); break;
					}
					for (var j = i; j < i + 10; ++j) {
						var thisCopy = baseColor.slice(0);
						for (var k = 0; k < 3; ++k) {
							thisCopy[k] = thisCopy[k] - 16 * (j - i);
							if (thisCopy[k] < 0) { thisCopy[k] = 0; }
						}
						sparseColorArray[j] = '#' + ('0'+thisCopy[0].toString(16)).substr(-2) + ('0'+thisCopy[1].toString(16)).substr(-2) + ('0'+thisCopy[2].toString(16)).substr(-2);
					}
				}
			}
			initColorArray();
			for (var m = 1; m < SHOWS.length; ++m)
				if (MOVIES[SHOWS[m].movie] && /^\d\d\d\d/.test(MOVIES[SHOWS[m].movie].release_date)) {
					var y = /^(\d\d\d\d)/.exec(MOVIES[SHOWS[m].movie].release_date)[1];
					if (years[y])
						++years[y];
					else 
						years[y] = 1;
				}
			var labelData = Array(),valueData = Array(), bkgColor = Array(), saving = 0;
			for (var iter = 1900; iter < years.length; ++iter) {
				if (years[iter] > 0 || saving) {
					saving = 1;
					labelData.push(iter);
					valueData.push(years[iter]);
					bkgColor.push(sparseColorArray[iter]);
				}

			}
			return {
				type: 'bar',
				data: { 
					datasets: [{
						label: 'Movies grouped by release year',
						"data": valueData,
						backgroundColor: bkgColor,
						datalabels: {
							display: false
						}
					}],
					labels: labelData
				},
				options: {
					legend: { display: false }, 
					title: { display: true, text: "Movies grouped by decade", fontSize: 14 },
					tooltips: {
						callbacks: {
							label: function(tooltipItem, data) {
								var thisYear = tooltipItem.xLabel;
								var tlist = [];
								for (var iter = 1; iter < SHOWS.length; ++iter)  {
									try {
										if (SHOWS[iter] && SHOWS[iter].movie && parseInt(MOVIES[SHOWS[iter].movie].release_date) == thisYear) {
											tlist.push(MOVIES[SHOWS[iter].movie].title);
										}
									} catch (error) { console.log('failed at iter = ' + iter); console.error(error); }
								}
								return tlist;
							}
						}
					},
					scales: {
						yAxes: [{
							ticks: {
								beginAtZero: true
							}
						}]
					}
				}
			}; 
		}
	},
	{
		"title": "Stars in most movies",
		"id": "people-rank",
		"graphType": "people-list",
		"prepFn": function() {
			var starCount = Array(), personSort = Array(), tooltipArray = Array();
			for (var iter = 1; iter < SHOWS.length; ++iter) {
				if (SHOWS[iter] === null || SHOWS[iter].movie === null)
					continue;
				for (var j = 0; j < MOVIES[SHOWS[iter].movie].cast.length; ++j) {
					castId = MOVIES[SHOWS[iter].movie].cast[j];
					if (tooltipArray[castId] == null)
						tooltipArray[castId] = Array();
					tooltipArray[castId].push(MOVIES[SHOWS[iter].movie].title);
					if (! starCount[castId]) starCount[castId] = 0;
					++starCount[castId];
				}
			}

			var pids = Object.keys(PEOPLE);
			for (var n = 0; n < pids.length; ++n) {
				var e = pids[n];
				if (starCount[e] > 0) {
					personSort.push({ id: e, name: PEOPLE[e], value: starCount[e]});
				}
			}
			personSort.sort(BAVALUE);
			var labelArray = Array(), personIdArray = Array(), valueArray = Array();
			for (var i = 0; i < 25; ++i) {
				labelArray[i] = personSort[i].name;
				valueArray[i] = personSort[i].value;
				personIdArray[i] = personSort[i].id;
			}
			return {
				type: 'horizontalBar',
				data: {
					datasets: [{
						label: "The stars in the most films",
						data: valueArray,
						backgroundColor: COLOR25,
						datalabels: {
							display: false
						}
					}],
					labels: labelArray
				},
				options: {
					legend: { display: false }, 
					title: { display: true, text: "The stars in the most films", fontSize: 14 },
					tooltips: {
						position: 'atMouse',
						callbacks: {
							label: function(tooltipItem, data) {
								var num = tooltipItem.index;
								return tooltipArray[personIdArray[num]];
							}
						}
					},
					scales: {
						xAxes: [{
							ticks: {
								beginAtZero: true
							}
						}]
					}
				}
			};
		}
	},
	{
		"title": "Most frequent guests",
		"id": "guest-hosts",
		"graphType": "people-list",
		"prepFn": function() {
			var n;
			var guestCount = Array(),objArray = Array(), tooltipArray = Array();
			for (var iter = 1; iter < SHOWS.length; ++iter) {
				if (SHOWS[iter] && SHOWS[iter].guests) {
					for (n = 0; n < SHOWS[iter].guests.length; ++n) {
						var value = SHOWS[iter].guests[n];
						guestCount[value] = isNaN(guestCount[value]) ? 1 : guestCount[value] + 1;
						if (! tooltipArray[value]) tooltipArray[value] = Array();
						tooltipArray[value].push(MOVIES[SHOWS[iter].movie].title);
					}
				}
			}
			for (n = 0, tmpArray = Object.keys(guestCount); n < tmpArray.length; ++n)
				objArray.push( { id: tmpArray[n], value: guestCount[tmpArray[n]], name: PEOPLE[tmpArray[n]] || tmpArray[n] });
			objArray.sort(BAVALUE);
			var labelArray = Array(), personIdArray = Array(), valueArray = Array();
			for (var i = 0; i < 25; ++i) {
				labelArray[i] = objArray[i].name;
				valueArray[i] = objArray[i].value;
				personIdArray[i] = objArray[i].id;
			}
			return {
				type: 'horizontalBar',
				data: {
					datasets: [{
						label: "The most frequent guests",
						data: valueArray,
						backgroundColor: COLOR25,
						datalabels: {
							display: false
						}
					}],
					labels: labelArray
				},
				options: {
					legend: { display: false }, 
					title: { display: true, text: "The most frequent guests", fontSize: 14 },
					tooltips: {
						position: 'atMouse',
						callbacks: {
							label: function(tooltipItem, data) {
								var num = tooltipItem.index;
								return tooltipArray[personIdArray[num]];
							}
						}
					},
					scales: {
						xAxes: [{
							ticks: {
								beginAtZero: true
							}
						}]
					}
				}
			};

		}
	},
	{
		"title": "Most expensive movies",
		"id": "movie-budget",
		"graphType": "movies-list",
		"prepFn": function() {
			var sortArray = Array();
			for (var iter = 1; iter < SHOWS.length; ++iter) {
				if (! SHOWS[iter]) continue;
				if (! SHOWS[iter].movie) continue;
				sortArray.push({ id: SHOWS[iter].movie, value: MOVIES[SHOWS[iter].movie].budget });
			}
			sortArray.sort(BAVALUE);
			var labelArray = Array(), movieIdArray = Array(), valueArray = Array();
			for (var i = 0; i < 25; ++i) {
				labelArray[i] = MOVIES[sortArray[i].id].title;
				valueArray[i] = sortArray[i].value;
				movieIdArray[i] = sortArray[i].id;
			}
			return {
				type: 'horizontalBar',
				data: {
					datasets: [{
						label: "The most expensive movies",
						data: valueArray,
						backgroundColor: COLOR25,
						datalabels: {
							display: false
						}
					}],
					labels: labelArray
				},
				options: {
					legend: { display: false }, 
					title: { display: true, text: "The most expensive movies", fontSize: 14 },
					tooltips: {
						position: 'atMouse',
						callbacks: {
							label: function(tooltipItem, data) {
								var dollars = tooltipItem.xLabel;
								return '$' + dollars.toString().replace(/(\d)(?=(\d{3})+(?!\d))/g, "$1,");
							}
						}
					},
					scales: {
						xAxes: [{
							ticks: {
								beginAtZero: true
							}
						}]
					}
				}
			};

		}
	},
	{
		"title": "Least profitable movies",
		"id": "movie-least-profit",
		"graphType": "movies-list",
		"prepFn": function() {
			var sortArray = Array();
			for (var iter = 1; iter < SHOWS.length; ++iter) {
				if (! SHOWS[iter]) continue;
				if (! SHOWS[iter].movie) continue;
				if (MOVIES[SHOWS[iter].movie].budget > 0 && MOVIES[SHOWS[iter].movie].revenue > 0)
					sortArray.push({ id: SHOWS[iter].movie, 
						budget: MOVIES[SHOWS[iter].movie].budget,
						revenue: MOVIES[SHOWS[iter].movie].revenue,
						value: MOVIES[SHOWS[iter].movie].revenue / MOVIES[SHOWS[iter].movie].budget });
			}
			sortArray.sort(ABVALUE);
			var labelArray = Array(), movieIdArray = Array(), valueArray = Array(), tooltipArray = Array();
			for (var i = 0; i < 25; ++i) {
				labelArray[i] = MOVIES[sortArray[i].id].title;
				valueArray[i] = sortArray[i].value * 100;
				movieIdArray[i] = sortArray[i].id;
				tooltipArray[i] = Array("Budget: $" + sortArray[i].budget.toString().replace(/(\d)(?=(\d{3})+(?!\d))/g, "$1,"),
					"Revenue: $"+sortArray[i].revenue.toString().replace(/(\d)(?=(\d{3})+(?!\d))/g, "$1,"),
					"Profit: " + String(Math.floor(sortArray[i].revenue / sortArray[i].budget * 10000) / 100) + '%'
					);
			}
			return {
				type: 'horizontalBar',
				data: {
					datasets: [{
						label: "The least profitable movies",
						data: valueArray,
						backgroundColor: COLOR25,
						datalabels: {
							display: false
						}
					}],
					labels: labelArray
				},
				options: {
					legend: { display: false }, 
					title: { display: true, text: "The most profitable movies", fontSize: 14 },
					tooltips: {
						position: 'atMouse',
						callbacks: {
							label: function(tooltipItem, data) {
								var num = tooltipItem.index;
								return tooltipArray[num];
							}
						}
					},
					scales: {
						xAxes: [{
							ticks: {
								beginAtZero: true
							}
						}]
					}
				}
			};
		}
	},
	{
		"title": "Most profitable movies",
		"id": "movie-profit",
		"graphType": "movies-list",
		"prepFn": function() {
			var sortArray = Array();
			for (var iter = 1; iter < SHOWS.length; ++iter) {
				if (! SHOWS[iter]) continue;
				if (! SHOWS[iter].movie) continue;
				if (MOVIES[SHOWS[iter].movie].budget > 0 && MOVIES[SHOWS[iter].movie].revenue > 0)
					sortArray.push({ id: SHOWS[iter].movie, 
						budget: MOVIES[SHOWS[iter].movie].budget,
						revenue: MOVIES[SHOWS[iter].movie].revenue,
						value: MOVIES[SHOWS[iter].movie].revenue / MOVIES[SHOWS[iter].movie].budget });
			}
			sortArray.sort(BAVALUE);
			var labelArray = Array(), movieIdArray = Array(), valueArray = Array(), tooltipArray = Array();
			for (var i = 0; i < 25; ++i) {
				labelArray[i] = MOVIES[sortArray[i].id].title;
				valueArray[i] = sortArray[i].value * 100;
				movieIdArray[i] = sortArray[i].id;
				tooltipArray[i] = Array("Budget: $" + sortArray[i].budget.toString().replace(/(\d)(?=(\d{3})+(?!\d))/g, "$1,"),
					"Revenue: $"+sortArray[i].revenue.toString().replace(/(\d)(?=(\d{3})+(?!\d))/g, "$1,"),
					"Profit: " + String(Math.floor(sortArray[i].revenue / sortArray[i].budget * 10000) / 100) + '%'
					);
			}
			return {
				type: 'horizontalBar',
				data: {
					datasets: [{
						label: "The most profitable movies",
						data: valueArray,
						backgroundColor: COLOR25,
						datalabels: {
							display: false
						}
					}],
					labels: labelArray
				},
				options: {
					legend: { display: false }, 
					title: { display: true, text: "The least profitable movies", fontSize: 14 },

					tooltips:  {
						position: 'atMouse',
						callbacks: {
							label: function(tooltipItem, data) {
								var num = tooltipItem.index;
								return tooltipArray[num];
							}
						}
					},
					scales: {
						xAxes: [{
							ticks: {
								beginAtZero: true
							}
						}]
					}
				}
			};
		}
	}	
];
