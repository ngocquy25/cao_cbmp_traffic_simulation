/**
* Name: Vehicles
* Based on the internal empty template. 
* Author: PC
* Tags: 
*/


model Vehicles
import "Road.gaml"
import "Intersection.gaml"
import "Roi.gaml"
import "Main.gaml"

/* Insert your model definition here */
species vehicle skills: [driving] {

	//obj for vehicle width - chieu ngang phuong tien, duoc ghi de boi tung loai con
	float vehicle_width <- 1.0;
	float total_delay <- 0.0;
	float lateral_offset <- 0.0; // Do lech ngang ngau nhien mo phong dong xe hon don
	float stop_distance <- 4.0;  // Khoang cach dung truoc den do
	traffic_light_visual light_ahead <- nil; // Den tin hieu phia truoc
	float dist_to_light <- #infinity;        // Khoang cach den den tin hieu phia truoc

	init {
		right_side_driving <- true;
		safety_distance_coeff <- 1.0;
		min_safety_distance <- 0.6;
	}

	road previous_road <- nil;
	//find road
	reflex move {
		if (final_target = nil or (location distance_to final_target.location < 5.0)) {
			do die;
		}
		else{
			// Accumulate stopped delay if speed is very low (< 1 km/h = 0.28 m/s)
			if (speed < 0.28) {
				total_delay <- total_delay + step;
			}

			if (current_path = nil) {
				do compute_path graph: road_network target: final_target;
				if (current_path = nil) {
					// remove if no path available
					//write "vehicle killed due to no path";
					do die;
					return;
				}
			}	
			
			// obj for throughput tracking - dem so xe roi khoi nga tu
			if (current_road != previous_road) {
				if (previous_road != nil) {
					intersection crossed_node <- intersection(road_network target_of road(previous_road));
					if (crossed_node != nil and crossed_node.is_traffic_signal) {
						// Only count throughput if the previous road was NOT an internal link within the cluster
						intersection source_node <- intersection(road_network source_of road(previous_road));
						bool is_internal_link <- (source_node != nil and source_node.is_traffic_signal);
						
						ask crossed_node { 
							if (!is_internal_link) {
								throughput_count <- throughput_count + 1; 
							}
							total_delay_in_cycle <- total_delay_in_cycle + myself.total_delay;
						}
						total_delay <- 0.0; // reset vehicle delay after crossing
					}
				}
				previous_road <- road(current_road);
			}
			// =========================================================================
			// TRAFFIC LIGHT LOGIC (UNIFIED FOR ALL ALGORITHMS - CHUẨN THEO BẢN CAO)
			// =========================================================================
			bool should_stop <- false;
			bool should_slow <- false;
			dist_to_light <- #infinity;

			light_ahead <- traffic_light_visual closest_to self;
			dist_to_light <- (light_ahead != nil) ? (self distance_to light_ahead) : #infinity;

			if (light_ahead != nil and (light_ahead.state = "red" or light_ahead.state = "yellow")) {
				float angle_to_light <- float(self towards light_ahead);
				float diff_ang <- abs(angle_to_light - heading) mod 360.0;
				if (diff_ang > 180.0) { diff_ang <- 360.0 - diff_ang; }
				
				// Đèn đỏ hoặc vàng nằm phía trước mặt xe
				if (diff_ang < 90.0 and dist_to_light > 0.5) {
					if (light_ahead.state = "red") {
						// Khi đèn ĐỎ: dừng hẳn trước vạch
						if (dist_to_light < stop_distance) { 
							should_stop <- true; 
						} else if (dist_to_light < stop_distance + 20.0) { 
							should_slow <- true; 
						}
					} else if (light_ahead.state = "yellow") {
						// Khi đèn VÀNG: Nếu ở cự ly an toàn thì phanh giảm tốc dần để dừng; nếu sát vạch (< stop_distance) thì tiếp tục vượt giải tỏa nút
						if (dist_to_light >= stop_distance and dist_to_light < stop_distance + 20.0) {
							should_slow <- true; 
						}
					}
				}
			}

			// =========================================================================
			// 3. DI CHUYỂN VÀ ĐIỀU KHIỂN TỐC ĐỘ QUA NGÃ TƯ (KHÔNG DỪNG GIỮA TIM NÚT)
			// =========================================================================
			intersection next_node <- (current_road != nil) ? intersection(road_network target_of road(current_road)) : nil;
			intersection prev_node <- (previous_road != nil) ? intersection(road_network target_of road(previous_road)) : nil;
			bool in_intersection_zone <- (next_node != nil and next_node.is_traffic_signal and self distance_to next_node.location < 25.0) 
				or (prev_node != nil and prev_node.is_traffic_signal and self distance_to prev_node.location < 25.0);

			if (should_stop) {
				speed <- 0.0;
			} else if (should_slow) {
				float brake_ratio <- max(0.0, (dist_to_light - stop_distance) / 20.0);
				speed <- min(max_speed * brake_ratio * 0.4, intersection_speed_limit);
				do drive;
			} else {
				// Nếu đang đứng yên (hết đèn đỏ chuyển sang xanh), lập tức xuất phát
				if (speed = 0.0) { 
					speed <- min(max_speed * 0.35, intersection_speed_limit * 0.7); 
				}
				
				// Khi đi trong phạm vi ngã tư:
				// Giới hạn tốc độ theo intersection_speed_limit nhưng duy trì tối thiểu >= 4 km/h để thoát nút
				if (in_intersection_zone) {
					speed <- min(speed, intersection_speed_limit);
					if (speed < 4.0 #km/#h) {
						speed <- min(4.0 #km/#h, intersection_speed_limit);
					}
				}
				do drive;
			}
		}
		
	}
// ROI detection is now handled by roi_lane self-scan (removed vehicle-push approach)
	action compute_position type: point {
		if (current_road != nil) {
			float road_width <- road(current_road).width;
			int n_lanes <- road(current_road).num_lanes;
			float lane_w <- road_width / n_lanes;

			// Vị trí tâm phương tiện nằm ở giữa các tiểu làn mà xe chiếm dụng
			float dist_from_left_edge <- (n_lanes - lowest_lane - (num_lanes_occupied / 2.0)) * lane_w;
			float center_offset <- dist_from_left_edge - (road_width / 2);
			float final_dist <- -center_offset + lateral_offset;
			point shift_pt <- {cos(heading + 90) * final_dist, sin(heading + 90) * final_dist};
			return location + shift_pt;
		} else {
			return location;
		}

	}

}

species motobike parent: vehicle {

	// =========================================================================
	// CÁC BIẾN TRẠNG THÁI CHO 3 HÀNH VI ĐẶC TRƯNG XE MÁY [7, 11]
	// =========================================================================
	// Hành vi 1: Di chuyển phi làn đường (tọa độ ngang dao động liên tục)
	float lateral_drift <- 0.0;
	
	// Hành vi 3: Tập hợp thành cụm và xả cụm
	bool is_in_platoon <- false;

	init {
		vehicle_length <- 1.9;
		vehicle_width <- 0.7;
		num_lanes_occupied <- 1; // Xe máy chiếm 1 tiểu làn (0.875m) -> tận dụng toàn bộ bề rộng mặt đường
		
		// IDM Car-following parameters (Bám đuôi sát, phản xạ nhanh)
		min_safety_distance <- 0.4;
		safety_distance_coeff <- 0.6;
		time_headway <- 0.3;
		max_acceleration <- 2.8;
		max_deceleration <- 4.5;
		
		// MOBIL Lane-changing parameters (Lọc qua khe hở cực kỳ linh hoạt)
		acc_gain_threshold <- 0.01; // Ngưỡng gia tốc cực thấp -> sẵn sàng chuyển tiểu làn ngay khi có khe hở
		politeness_factor <- 0.0;   // Chen lấn, không nhường xe lớn
		lane_change_limit <- 2;     // Cho phép lách qua 2 tiểu làn để vượt qua xe lớn
		stop_distance <- 6.0;       // Dừng sát vạch dừng hơn ô tô và xe tải -> Đảo trật tự xếp hàng
		
		max_speed <- rnd(40.0, 55.0) #km / #h;
		speed <- max_speed;
		
		lateral_drift <- rnd(-0.2, 0.2);
		lateral_offset <- lateral_drift;
	}

	// =========================================================================
	// HÀNH VI 1: DI CHUYỂN PHI LÀN ĐƯỜNG (NON-LANE-BASED 2D MOVEMENT) [7, 11]
	// Tận dụng khoảng trống trên toàn bộ bề rộng mặt đường, vị trí xác định bằng 2 tọa độ (dọc và ngang)
	// =========================================================================
	reflex non_lane_based_maneuver when: speed > 2.0 #km/#h {
		lateral_drift <- lateral_drift + rnd(-0.03, 0.03);
		if (lateral_drift > 0.3) { lateral_drift <- 0.3; }
		if (lateral_drift < -0.3) { lateral_drift <- -0.3; }
		lateral_offset <- lateral_drift;
	}

	// =========================================================================
	// HÀNH VI 2: LỌC QUA KHE HỞ & ĐẢO TRẬT TỰ XẾP HÀNG (GAP FILTERING & QUEUE INVERSION) [11]
	// Khi xe lớn giảm tốc/dừng, xe máy luồn qua các khe hở lên trước vạch dừng, đẩy xe lớn ra phía sau
	// =========================================================================
	reflex filter_through_gaps when: current_road != nil and (speed < 20.0 #km/#h or dist_to_light < 35.0) {
		road cur_rd <- road(current_road);
		
		point my_loc <- self.location;
		float my_heading <- float(heading);
		
		// Tìm các xe lớn (ô tô, xe tải) đang đi chậm hoặc dừng phía trước trong khoảng 12m
		list<vehicle> large_vehicles_ahead <- ((car as list) + (truck as list)) where (
			road(each.current_road) = cur_rd and
			each != self and
			(my_loc distance_to each.location) < 12.0 and
			(cos(float(my_loc towards each.location) - my_heading) > 0.6)
		);
		
		if (!empty(large_vehicles_ahead)) {
			// Lách người và dạt sang mép ngoài để tận dụng khe hở vượt lên
			lateral_drift <- (lateral_drift >= 0.0) ? 0.3 : -0.3;
			lateral_offset <- lateral_drift;
		}
	}

	// =========================================================================
	// HÀNH VI 3: TẬP HỢP THÀNH CỤM (PHA ĐỎ) & XẢ CỤM ĐỒNG LOẠT (PHA XANH) [11]
	// Pha đỏ: Dồn lại thành cụm 2 chiều dày đặc trước vạch dừng, chiếm hết bề rộng mặt đường
	// Pha xanh: Thoát qua nút giao gần như đồng loạt, không tách thành hàng đơn như ô tô
	// =========================================================================
	reflex platoon_dynamics when: current_road != nil {
		bool red_ahead <- (light_ahead != nil and light_ahead.state = "red" and dist_to_light < 25.0);
		bool green_ahead <- (light_ahead != nil and light_ahead.state = "green" and dist_to_light < 25.0);
		
		if (red_ahead) {
			// --- PHA ĐỎ: TẬP HỢP THÀNH CỤM 2D DÀY ĐẶC TRƯỚC VẠCH DỪNG ---
			if (dist_to_light < 15.0) {
				is_in_platoon <- true;
				// Co ngắn khoảng cách an toàn để nén chặt vào cụm
				min_safety_distance <- 0.35;
				safety_distance_coeff <- 0.5;
				time_headway <- 0.2;
			}
		} else if (green_ahead and is_in_platoon) {
			// --- PHA XANH: XẢ CỤM ĐỒNG LOẠT (SIMULTANEOUS BULK DISCHARGE) ---
			// Cả cụm xe máy đồng loạt bứt tốc xuất phát cùng lúc, không chờ time headway như ô tô
			is_in_platoon <- false;
			max_acceleration <- 3.5; // Gia tốc tức thời cực lớn
			time_headway <- 0.2;     // Xuất phát đồng thời không có trễ hàng đợi
			if (speed < 5.0 #km/#h) {
				speed <- min(15.0 #km/#h, intersection_speed_limit); // Vọt đồng loạt qua vạch dừng
			}
		} else if (dist_to_light >= 25.0 and !is_in_platoon) {
			// Khôi phục thông số IDM bình thường khi đã ra khỏi cụm nút giao
			max_acceleration <- 2.8;
			time_headway <- 0.3;
			min_safety_distance <- 0.4;
			safety_distance_coeff <- 0.6;
		}
	}

	aspect default {
		point pos <- compute_position();
		draw box(1.9, 0.7, 1.2) color: #brown rotate: heading at: {pos.x, pos.y, 0.5};
	}

	// heatmap point display
	aspect heat_dot {
		draw circle(10) color: rgb(255, 60, 0, 80);
	}

}

species car parent: vehicle {

	init {
		vehicle_length <- 4.5;
		vehicle_width <- 1.8;
		num_lanes_occupied <- 2; // O to con chiem 2 tieu lan (~1.75m)
		
		// IDM Car-following parameters (Lai xe can trong, giu khoang cach an toan)
		min_safety_distance <- 0.8;
		safety_distance_coeff <- 1.0;
		time_headway <- 0.8;
		max_acceleration <- 1.2;
		max_deceleration <- 3.0;
		
		// MOBIL Lane-changing parameters (Chuyen lan tieu chuan)
		acc_gain_threshold <- 0.2;
		politeness_factor <- 0.4;
		lane_change_limit <- 1;
		stop_distance <- 7.5;       // Dung truoc vach 7.5m de xe may luon len phia truoc (Dao trat tu xep hang)
		
		max_speed <- rnd(30.0, 50.0) #km / #h;
		speed <- max_speed;
		lateral_offset <- 0.0;
	}

	aspect default {
		point pos <- compute_position();
		draw box(4.5, 1.8, 1.5) color: #purple rotate: heading at: {pos.x, pos.y, 1};
	}

	// larger heatmap point for car
	aspect heat_dot {
		draw circle(13) color: rgb(255, 60, 0, 90);
	}

}

species truck parent: vehicle {

	init {
		vehicle_length <- 8.0;
		vehicle_width <- 2.4;
		num_lanes_occupied <- 3; // Xe tai chiem 3 tieu lan (~2.6m)
		
		// IDM Car-following parameters (Xe nang, giu khoang cach lon hon)
		min_safety_distance <- 1.2;
		safety_distance_coeff <- 1.2;
		time_headway <- 1.2;
		max_acceleration <- 0.7;
		max_deceleration <- 2.5;
		
		// MOBIL Lane-changing parameters (Rat it khi chuyen lan)
		acc_gain_threshold <- 0.5;
		politeness_factor <- 0.6;
		lane_change_limit <- 1;
		stop_distance <- 9.0;       // Dung sau xe con
		
		max_speed <- rnd(20.0, 40.0) #km / #h;
		speed <- max_speed;
		lateral_offset <- 0.0;
	}

	aspect default {
		point pos <- compute_position();
		draw box(8.0, 2.4, 2.8) color: #pink rotate: heading at: {pos.x, pos.y, 1.5};
	}

	// largest heatmap point for truck
	aspect heat_dot {
		draw circle(16) color: rgb(255, 60, 0, 100);
	}
}


