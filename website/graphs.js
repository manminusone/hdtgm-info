

// surprising that this tooltip position isn't standard!
Chart.Tooltip.positioners.atMouse = function(elements, eventPosition) {
    /** @type {Chart.Tooltip} */
    console.log(elements);
    console.log(eventPosition);

    return eventPosition;
}

// graphs data
function showGraph(which) { 
	$('#body-div').hide();
	$('canvas').addClass('graph-hide');
	$('#c-'+GRAPH[which].id).removeClass('graph-hide');
	var ctx = document.getElementById('c-'+GRAPH[which].id).getContext('2d');
	var d = GRAPH[which].prepFn();
	var chart = new Chart(ctx, d);
}

var liveCount = 0, studioCount = 0;
var GRAPH = [
	{
		"id" : "live-shows",
		"title" :  "Number of live and studio shows",
		"prepFn": function() { 
	 		liveCount = 0; studioCount = 0;
	 		for (var m = 1; m < SHOWS.length; ++m)
	 			if (SHOWS[m] && SHOWS[m].live == 1)
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
    							return value + ': ' + Math.round((value / (liveCount + studioCount)) * 100) + '%';
							}
	 					}
	 				}],
	 				labels: [
	 					'Live episodes',
	 					'Studio episodes'
	 				]
	 			}
	 		};
		 },
	},
	{
		"title": "Sort by year",
		"id": "year-count",
		"prepFn": function() {
			var sparseColorArray = Array();
			var years = new Array();
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
			var labelData = Array(),valueData = Array(), bkgColor = Array();
			for (var iter = 1900; iter < years.length; ++iter) {
				if (years[iter] > 0) {
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
					tooltips: {
						callbacks: {
							label: function(tooltipItem, data) {
								var thisYear = tooltipItem.xLabel;
								var tlist = new Array();
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
				},
			}; 
		}
	},
	{
		"title": "Sort by decade",
		"id": "decade-count",
		"prepFn": function() {
			var sparseColorArray = Array();
			var years = new Array();
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
				if (SHOWS[m].movie != null && MOVIES[SHOWS[m].movie] && /^\d\d\d\d/.test(MOVIES[SHOWS[m].movie].release_date)) {
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
					scales: {
						yAxes: [{
							ticks: {
								beginAtZero: true
							}
						}]
					}
				},
			}; 
		}
	},
	{
		"title": "Stars in most movies",
		"id": "people-rank",
		"prepFn": function() {
			var starCount = Array(), personSort = Array(), tooltipArray = Array();
			for (var iter = 1; iter < SHOWS.length; ++iter) {
				if (SHOWS[iter] == null || SHOWS[iter].movie == null)
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

			var iter = PEOPLE.entries();
			for (let e of iter) {
				if (starCount[e[0]] > 0)
					personSort.push({ id: e[0], name: e[1], val: starCount[e[0]]});
			}
			personSort.sort(function (a,b) { return b.val - a.val });
			// console.log(personSort.slice(0,10));
			var labelArray = Array(), personIdArray = Array(), valueArray = Array();
			for (var i = 0; i < 25; ++i) {
				labelArray[i] = personSort[i].name;
				valueArray[i] = personSort[i].val;
				personIdArray[i] = personSort[i].id;
			}
			// console.log(labelArray);
			// console.log(valueArray);
			return {
				type: 'horizontalBar',
				data: {
					datasets: [{
						label: "The stars in the most films",
						data: valueArray,
						backgroundColor: [ '#00ff80','#33cc80','#669980','#996680','#993300','#ff0000','#cc0033','#990066','#660099','#3300cc','#0000ff','#0033cc','#006699','#009966','#00cc33','#00ff00','#00ff33','#00ff66','#00ff99','#00ffcc','#00ffff','#00cccc','#339999','#665599','#990099' ],
						datalabels: {
							display: false
						}
					}],
					labels: labelArray
				},
				options: {
					tooltips: {
						position: 'atMouse',
						callbacks: {
							label: function(tooltipItem, data) {
								// console.log(tooltipItem);
								// console.log(data);
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
	}
];