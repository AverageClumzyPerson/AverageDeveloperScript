--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
local module = {}
local eps = 1e-9

local function isZero(d)
	return (d > -eps and d < eps)
end

local function cuberoot(x)
	return (x > 0) and math.pow(x, (1 / 3)) or -math.pow(math.abs(x), (1 / 3))
end

local function solveQuadric(c0, c1, c2)
	local p, q, D
	p = c1 / (2 * c0)
	q = c2 / c0
	D = p * p - q

	if isZero(D) then
		return -p
	elseif (D < 0) then
		return
	else 
		local sqrt_D = math.sqrt(D)
		return sqrt_D - p, -sqrt_D - p
	end
end

local function solveCubic(c0, c1, c2, c3)
	local num, sub
	local A, B, C
	local sq_A, p, q
	local cb_p, D

	A = c1 / c0
	B = c2 / c0
	C = c3 / c0

	sq_A = A * A
	p = (1 / 3) * (-(1 / 3) * sq_A + B)
	q = 0.5 * ((2 / 27) * A * sq_A - (1 / 3) * A * B + C)

	cb_p = p * p * p
	D = q * q + cb_p

	local s0, s1, s2

	if isZero(D) then
		if isZero(q) then 
			s0 = 0
			num = 1
		else 
			local u = cuberoot(-q)
			s0 = 2 * u
			s1 = -u
			num = 2
		end
	elseif (D < 0) then 
		local phi = (1 / 3) * math.acos(-q / math.sqrt(-cb_p))
		local t = 2 * math.sqrt(-p)

		s0 = t * math.cos(phi)
		s1 = -t * math.cos(phi + math.pi / 3)
		s2 = -t * math.cos(phi - math.pi / 3)
		num = 3
	else
		local sqrt_D = math.sqrt(D)
		local u = cuberoot(sqrt_D - q)
		local v = -cuberoot(sqrt_D + q)

		s0 = u + v
		num = 1
	end

	sub = (1 / 3) * A

	if (num > 0) then s0 = s0 - sub end
	if (num > 1) then s1 = s1 - sub end
	if (num > 2) then s2 = s2 - sub end

	return s0, s1, s2
end

function module.solveQuartic(c0, c1, c2, c3, c4)
	if isZero(c0) then
		if isZero(c1) then
			if isZero(c2) then
				if isZero(c3) then return {} end
				return {-c4 / c3}
			end
			local r1, r2 = solveQuadric(c2, c3, c4)
			local res = {}
			if r1 then table.insert(res, r1) end
			if r2 then table.insert(res, r2) end
			return res
		end
		local r1, r2, r3 = solveCubic(c1, c2, c3, c4)
		local res = {}
		if r1 then table.insert(res, r1) end
		if r2 then table.insert(res, r2) end
		if r3 then table.insert(res, r3) end
		return res
	end

	local s0, s1, s2, s3
	local coeffs = {}
	local z, u, v, sub
	local A, B, C, D
	local sq_A, p, q, r
	local num

	A = c1 / c0
	B = c2 / c0
	C = c3 / c0
	D = c4 / c0

	sq_A = A * A
	p = -0.375 * sq_A + B
	q = 0.125 * sq_A * A - 0.5 * A * B + C
	r = -(3 / 256) * sq_A * sq_A + 0.0625 * sq_A * B - 0.25 * A * C + D

	if isZero(r) then
		coeffs[3] = q
		coeffs[2] = p
		coeffs[1] = 0
		coeffs[0] = 1

		local results = {solveCubic(coeffs[0], coeffs[1], coeffs[2], coeffs[3])}
		num = #results
		s0, s1, s2 = results[1], results[2], results[3]
	else
		coeffs[3] = 0.5 * r * p - 0.125 * q * q
		coeffs[2] = -r
		coeffs[1] = -0.5 * p
		coeffs[0] = 1

		s0, s1, s2 = solveCubic(coeffs[0], coeffs[1], coeffs[2], coeffs[3])
		z = s0

		u = z * z - r
		v = 2 * z - p

		if isZero(u) then
			u = 0
		elseif (u > 0) then
			u = math.sqrt(u)
		else
			return {}
		end
		if isZero(v) then
			v = 0
		elseif (v > 0) then
			v = math.sqrt(v)
		else
			return {}
		end

		coeffs[2] = z - u
		coeffs[1] = q < 0 and -v or v
		coeffs[0] = 1

		local results1 = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
		num = #results1
		s0, s1 = results1[1], results1[2]

		coeffs[2] = z + u
		coeffs[1] = q < 0 and v or -v
		coeffs[0] = 1

		local results2 = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
		if (num == 0) then
			num = num + #results2
			s0, s1 = results2[1], results2[2]
		elseif (num == 1) then
			num = num + #results2
			s1, s2 = results2[1], results2[2]
		elseif (num == 2) then
			num = num + #results2
			s2, s3 = results2[1], results2[2]
		end
	end

	sub = 0.25 * A

	local res = {}
	if (num > 0 and s0) then table.insert(res, s0 - sub) end
	if (num > 1 and s1) then table.insert(res, s1 - sub) end
	if (num > 2 and s2) then table.insert(res, s2 - sub) end
	if (num > 3 and s3) then table.insert(res, s3 - sub) end

	return res
end

function module.SolveTrajectory(origin, projectileSpeed, gravity, targetPos, targetVelocity, playerGravity, playerHeight, ping, targetGravity)
	ping = ping or 0
	targetGravity = targetGravity or 0
	
	local predictedTargetPos = targetPos + targetVelocity * ping
	
	local disp = predictedTargetPos - origin
	local p, q, r = targetVelocity.X, targetVelocity.Y, targetVelocity.Z
	local h, j, k = disp.X, disp.Y, disp.Z
	
	local g_eff = gravity - targetGravity
	local l = -0.5 * g_eff

	local c0 = l * l
	local c1 = -2 * q * l
	local c2 = q * q - 2 * j * l - projectileSpeed * projectileSpeed + p * p + r * r
	local c3 = 2 * j * q + 2 * h * p + 2 * k * r
	local c4 = j * j + h * h + k * k

	local solutions = module.solveQuartic(c0, c1, c2, c3, c4)
	
	local function linearFallback()
		local t = disp.Magnitude / projectileSpeed
		if t <= 0 then return predictedTargetPos end
		local d = (h + p * t) / t
		local e = (j + q * t) / t + 0.5 * gravity * t
		local f = (k + r * t) / t
		return origin + Vector3.new(d, e, f)
	end

	if solutions and #solutions > 0 then
		local posRoots = {}
		for _, v in ipairs(solutions) do
			if v > 0.001 then
				table.insert(posRoots, v)
			end
		end
		table.sort(posRoots)

		if #posRoots > 0 then
			local t = posRoots[1]
			local aimX = (h + p * t) / t
			local aimY = (j + q * t - l * t * t) / t
			local aimZ = (k + r * t) / t
			
			local hitboxOffset = playerHeight and (playerHeight * 0.6) or 1.5
			
			return origin + Vector3.new(aimX, aimY + hitboxOffset, aimZ)
		end
	end

	return linearFallback()
end

return module
