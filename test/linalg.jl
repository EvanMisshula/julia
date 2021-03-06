n     = 10
srand(1234321)
a     = rand(n,n)
b     = rand(n)
for elty in (Float32, Float64, Complex64, Complex128)
        a     = convert(Matrix{elty}, a)
        asym  = a' + a                  # symmetric indefinite
        apd   = a'*a                    # symmetric positive-definite
        b     = convert(Vector{elty}, b)

        capd  = factorize(apd)              # (Automatic) upper Cholesky factor
        r     = capd[:U]
        @test_approx_eq r'*r apd
        @test_approx_eq b apd * (capd\b)
        @test_approx_eq apd * inv(capd) eye(elty, n)
        @test_approx_eq a*(capd\(a'*b)) b # least squares soln for square a
        @test_approx_eq det(capd) det(apd)
        @test_approx_eq logdet(capd) log(det(capd)) # logdet is less likely to overflow

        l     = cholfact(apd, :L)[:L] # lower Cholesky factor
        @test_approx_eq l*l' apd

        cpapd = cholpfact(apd)                          # pivoted Choleksy decomposition
        @test rank(cpapd) == n
        @test all(diff(diag(real(cpapd.UL))).<=0.) # diagonal should be non-increasing
        @test_approx_eq b apd * (cpapd\b)
        @test_approx_eq apd * inv(cpapd) eye(elty, n)

        bc1   = factorize(asym) # (Automatic) Bunch-Kaufman factor of indefinite matrix
        @test_approx_eq inv(bc1) * asym eye(elty, n)
        @test_approx_eq asym * (bc1\b) b
        bc2   = bkfact(apd) # Bunch-Kaufman factors of a pos-def matrix
        @test_approx_eq inv(bc2) * apd eye(elty, n)
        @test_approx_eq apd * (bc2\b) b

        lua   = factorize(a)                  # (Automatic) Square LU decomposition
        l,u,p = lua[:L], lua[:U], lua[:p]
        @test_approx_eq l*u a[p,:]
        @test_approx_eq l[invperm(p),:]*u a
        @test_approx_eq a * inv(lua) eye(elty, n)
        @test_approx_eq a*(lua\b) b

        lua   = lufact(a[:,1:5])              # Thin LU
        @test_approx_eq lua[:L]*lua[:U] lua[:P]*a[:,1:5]

        lua   = lufact(a[1:5,:])              # Fat LU
        @test_approx_eq lua[:L]*lua[:U] lua[:P]*a[1:5,:]

        qra   = qrfact(a)                  # QR decomposition
        q,r   = qra[:Q], qra[:R]
        @test_approx_eq q'*full(q, false) eye(elty, n)
        @test_approx_eq q*full(q, false)' eye(elty, n)
        @test_approx_eq q*r a
        @test_approx_eq a*(qra\b) b
        
        qrpa  = factorize(a[1:5,:])                 # (Automatic) Fat pivoted QR decomposition
        q,r,p = qrpa[:Q], qrpa[:R], qrpa[:p]
        @test_approx_eq q'*full(q, false) eye(elty, 5)
        @test_approx_eq q*full(q, false)' eye(elty, 5)
        @test_approx_eq q*r a[1:5,p]
        @test_approx_eq q*r[:,invperm(p)] a[1:5,:]
        @test_approx_eq a[1:5,:]*(qrpa\b[1:5]) b[1:5]

        qrpa  = factorize(a[:,1:5])                 # (Automatic) Thin pivoted QR decomposition
        q,r,p = qrpa[:Q], qrpa[:R], qrpa[:p]
        @test_approx_eq q'*full(q, false) eye(elty, n)
        @test_approx_eq q*full(q, false)' eye(elty, n)
        @test_approx_eq q*r a[:,p]
        @test_approx_eq q*r[:,invperm(p)] a[:,1:5]

        d,v   = eig(asym)              # symmetric eigen-decomposition
        @test_approx_eq asym*v[:,1] d[1]*v[:,1]
        @test_approx_eq v*scale(d,v') asym

        d,v   = eig(a)                 # non-symmetric eigen decomposition
        for i in 1:size(a,2) @test_approx_eq a*v[:,i] d[i]*v[:,i] end

        # symmetric generalized eigenproblem
        a610 = a[:,6:10]
        f = eigfact(asym[1:5,1:5], a610'a610)
        @test_approx_eq asym[1:5,1:5]*f[:vectors] scale(a610'a610*f[:vectors], f[:values])
        @test_approx_eq f[:values] eigvals(asym[1:5,1:5], a610'a610)
        @test_approx_eq prod(f[:values]) prod(eigvals(asym[1:5,1:5]/(a610'a610)))

        # Non-symmetric generalized eigenproblem
        f = eigfact(a[1:5,1:5], a[6:10,6:10])
        @test_approx_eq a[1:5,1:5]*f[:vectors] scale(a[6:10,6:10]*f[:vectors], f[:values])
        @test_approx_eq f[:values] eigvals(a[1:5,1:5], a[6:10,6:10])
        @test_approx_eq prod(f[:values]) prod(eigvals(a[1:5,1:5]/a[6:10,6:10]))

        f = schurfact(a)             # Schur
        @test_approx_eq f[:vectors]*f[:Schur]*f[:vectors]' a
        @test_approx_eq sort(real(f[:values])) sort(real(d))
        @test_approx_eq sort(imag(f[:values])) sort(imag(d))
        @test istriu(f[:Schur]) || iseltype(a,Real)

        f = schurfact(a[1:5,1:5], a[6:10,6:10]) # Generalized Schur
        @test_approx_eq f[:Q]*f[:S]*f[:Z]' a[1:5,1:5]
        @test_approx_eq f[:Q]*f[:T]*f[:Z]' a[6:10,6:10]
        @test istriu(f[:S]) || iseltype(a,Real)
        @test istriu(f[:T]) || iseltype(a,Real)

        usv = svdfact(a)                # singular value decomposition
        @test_approx_eq usv[:U]*scale(usv[:S],usv[:Vt]) a
    
        gsvd = svdfact(a,a[1:5,:])         # Generalized svd
        @test_approx_eq gsvd[:U]*gsvd[:D1]*gsvd[:R]*gsvd[:Q]' a
        @test_approx_eq gsvd[:V]*gsvd[:D2]*gsvd[:R]*gsvd[:Q]' a[1:5,:]

        x = a \ b
        @test_approx_eq a*x b
    
        x = triu(a) \ b
        @test_approx_eq triu(a)*x b
    
        x = tril(a)\b
        @test_approx_eq tril(a)*x b

                                        # Test null
        a15null = null(a[:,1:5]')
        @test_approx_eq_eps norm(a[:,1:5]'a15null) zero(elty) n*eps(real(one(elty)))
        @test_approx_eq_eps norm(a15null'a[:,1:5]) zero(elty) n*eps(real(one(elty)))
        @test size(null(b), 2) == 0

                                        # Test pinv
        pinva15 = pinv(a[:,1:5])
        @test_approx_eq a[:,1:5]*pinva15*a[:,1:5] a[:,1:5]
        @test_approx_eq pinva15*a[:,1:5]*pinva15 pinva15
    
                                        # Complex vector rhs
        x = a\complex(b)
        @test_approx_eq a*x complex(b)
                                        # Test cond
        @test_approx_eq_eps cond(a, 1) 4.837320054554436e+02 0.01
        @test_approx_eq_eps cond(a, 2) 1.960057871514615e+02 0.01
        @test_approx_eq_eps cond(a, Inf) 3.757017682707787e+02 0.01
        @test_approx_eq_eps cond(a[:,1:5]) 10.233059337453463 0.01

                                        # Matrix square root
        asq = sqrtm(a)
        @test_approx_eq asq*asq a
        asymsq = sqrtm(asym)
        @test_approx_eq asymsq*asymsq asym
end

## Least squares solutions
a = [ones(20) 1:20 1:20]
b = reshape(eye(8, 5), 20, 2)
for elty in (Float32, Float64, Complex64, Complex128)
        a = convert(Matrix{elty}, a)
        b = convert(Matrix{elty}, b)

        x = a[:,1:2]\b[:,1]             # Vector rhs
        @test_approx_eq ((a[:,1:2]*x-b[:,1])'*(a[:,1:2]*x-b[:,1]))[1] convert(elty, 2.546616541353384)

        x = a[:,1:2]\b                  # Matrix rhs
        @test_approx_eq det((a[:,1:2]*x-b)'*(a[:,1:2]*x-b)) convert(elty, 4.437969924812031)

        x = a\b                         # Rank deficient
        @test_approx_eq det((a*x-b)'*(a*x-b)) convert(elty, 4.437969924812031)

                                        # Underdetermined minimum norm
        x = convert(Matrix{elty}, [1 0 0; 0 1 -1]) \ convert(Vector{elty}, [1,1])
        @test_approx_eq x convert(Vector{elty}, [1, 0.5, -0.5])

                                        # symmetric, positive definite
        @test_approx_eq inv(convert(Matrix{elty}, [6. 2; 2 1])) convert(Matrix{elty}, [0.5 -1; -1 3])
                                        # symmetric, indefinite
        @test_approx_eq inv(convert(Matrix{elty}, [1. 2; 2 1])) convert(Matrix{elty}, [-1. 2; 2 -1]/3)
end

## Test Julia fallbacks to BLAS routines
                                        # matrices with zero dimensions
@test ones(0,5)*ones(5,3) == zeros(0,3)
@test ones(3,5)*ones(5,0) == zeros(3,0)
@test ones(3,0)*ones(0,4) == zeros(3,4)
@test ones(0,5)*ones(5,0) == zeros(0,0)
@test ones(0,0)*ones(0,4) == zeros(0,4)
@test ones(3,0)*ones(0,0) == zeros(3,0)
@test ones(0,0)*ones(0,0) == zeros(0,0)
                                        # 2x2
A = [1 2; 3 4]
B = [5 6; 7 8]
@test A*B == [19 22; 43 50]
@test At_mul_B(A, B) == [26 30; 38 44]
@test A_mul_Bt(A, B) == [17 23; 39 53]
@test At_mul_Bt(A, B) == [23 31; 34 46]
Ai = A+(0.5*im).*B
Bi = B+(2.5*im).*A[[2,1],[2,1]]
@test Ai*Bi == [-21+53.5im -4.25+51.5im; -12+95.5im 13.75+85.5im]
@test Ac_mul_B(Ai, Bi) == [68.5-12im 57.5-28im; 88-3im 76.5-25im]
@test A_mul_Bc(Ai, Bi) == [64.5+5.5im 43+31.5im; 104-18.5im 80.5+31.5im]
@test Ac_mul_Bc(Ai, Bi) == [-28.25-66im 9.75-58im; -26-89im 21-73im]
                                        # 3x3
A = [1 2 3; 4 5 6; 7 8 9]-5
B = [1 0 5; 6 -10 3; 2 -4 -1]
@test A*B == [-26 38 -27; 1 -4 -6; 28 -46 15]
@test Ac_mul_B(A, B) == [-6 2 -25; 3 -12 -18; 12 -26 -11]
@test A_mul_Bc(A, B) == [-14 0 6; 4 -3 -3; 22 -6 -12]
@test Ac_mul_Bc(A, B) == [6 -8 -6; 12 -9 -9; 18 -10 -12]
Ai = A+(0.5*im).*B
Bi = B+(2.5*im).*A[[2,1,3],[2,3,1]]
@test Ai*Bi == [-44.75+13im 11.75-25im -38.25+30im; -47.75-16.5im -51.5+51.5im -56+6im; 16.75-4.5im -53.5+52im -15.5im]
@test Ac_mul_B(Ai, Bi) == [-21+2im -1.75+49im -51.25+19.5im; 25.5+56.5im -7-35.5im 22+35.5im; -3+12im -32.25+43im -34.75-2.5im]
@test A_mul_Bc(Ai, Bi) == [-20.25+15.5im -28.75-54.5im 22.25+68.5im; -12.25+13im -15.5+75im -23+27im; 18.25+im 1.5+94.5im -27-54.5im]
@test Ac_mul_Bc(Ai, Bi) == [1+2im 20.75+9im -44.75+42im; 19.5+17.5im -54-36.5im 51-14.5im; 13+7.5im 11.25+31.5im -43.25-14.5im]
                                        # Generic integer matrix multiplication
A = [1 2 3; 4 5 6] - 3
B = [2 -2; 3 -5; -4 7]
@test A*B == [-7 9; -4 9]
@test At_mul_Bt(A, B) == [-6 -11 15; -6 -13 18; -6 -15 21]
A = ones(Int, 2, 100)
B = ones(Int, 100, 3)
@test A*B == [100 100 100; 100 100 100]
A = rand(1:20, 5, 5) - 10
B = rand(1:20, 5, 5) - 10
@test At_mul_B(A, B) == A'*B
@test A_mul_Bt(A, B) == A*B'
                                        # Preallocated
C = Array(Int, size(A, 1), size(B, 2))
@test A_mul_B(C, A, B) == A*B
@test At_mul_B(C, A, B) == A'*B
@test A_mul_Bt(C, A, B) == A*B'
@test At_mul_Bt(C, A, B) == A'*B'
                                        # matrix algebra with subarrays of floats (stride != 1)
A = reshape(float64(1:20),5,4)
Aref = A[1:2:end,1:2:end]
Asub = sub(A, 1:2:5, 1:2:4)
b = [1.2,-2.5]
@test (Aref*b) == (Asub*b)
@test At_mul_B(Asub, Asub) == At_mul_B(Aref, Aref)
@test A_mul_Bt(Asub, Asub) == A_mul_Bt(Aref, Aref)
Ai = A + im
Aref = Ai[1:2:end,1:2:end]
Asub = sub(Ai, 1:2:5, 1:2:4)
@test Ac_mul_B(Asub, Asub) == Ac_mul_B(Aref, Aref)
@test A_mul_Bc(Asub, Asub) == A_mul_Bc(Aref, Aref)
                                        # syrk & herk
A = reshape(1:1503, 501, 3)-750.0
res = float64([135228751 9979252 -115270247; 9979252 10481254 10983256; -115270247 10983256 137236759])
@test At_mul_B(A, A) == res
@test A_mul_Bt(A',A') == res
cutoff = 501
A = reshape(1:6*cutoff,2*cutoff,3)-(6*cutoff)/2
Asub = sub(A, 1:2:2*cutoff, 1:3)
Aref = A[1:2:2*cutoff, 1:3]
@test At_mul_B(Asub, Asub) == At_mul_B(Aref, Aref)
Ai = A - im
Asub = sub(Ai, 1:2:2*cutoff, 1:3)
Aref = Ai[1:2:2*cutoff, 1:3]
@test Ac_mul_B(Asub, Asub) == Ac_mul_B(Aref, Aref)

                                        # Matrix exponential
for elty in (Float32, Float64, Complex64, Complex128)
        A1  = convert(Matrix{elty}, [4 2 0; 1 4 1; 1 1 4])
        eA1 = convert(Matrix{elty}, [147.866622446369 127.781085523181  127.781085523182;
        183.765138646367 183.765138646366  163.679601723179;
        71.797032399996  91.8825693231832 111.968106246371]')
        @test_approx_eq expm(A1) eA1

        A2  = convert(Matrix{elty}, 
            [29.87942128909879    0.7815750847907159 -2.289519314033932;
            0.7815750847907159 25.72656945571064    8.680737820540137;
            -2.289519314033932   8.680737820540137  34.39400925519054])
        eA2 = convert(Matrix{elty},
            [  5496313853692458.0 -18231880972009236.0 -30475770808580460.0;
             -18231880972009252.0  60605228702221920.0 101291842930249760.0;
             -30475770808580480.0 101291842930249728.0 169294411240851968.0])
        @test_approx_eq expm(A2) eA2

        A3  = convert(Matrix{elty}, [-131 19 18;-390 56 54;-387 57 52])
        eA3 = convert(Matrix{elty}, [-1.50964415879218 -5.6325707998812  -4.934938326092;
        0.367879439109187 1.47151775849686  1.10363831732856;
        0.135335281175235 0.406005843524598 0.541341126763207]')
        @test_approx_eq expm(A3) eA3

                                        # Hessenberg
        @test_approx_eq hessfact(A1)[:H] convert(Matrix{elty}, 
                        [4.000000000000000  -1.414213562373094  -1.414213562373095
                        -1.414213562373095   4.999999999999996  -0.000000000000000
                                         0  -0.000000000000002   3.000000000000000])
end

# Hermitian matrix exponential
A1 = randn(4,4) + im*randn(4,4)
A2 = A1 + A1'
@test_approx_eq expm(A2) expm(Hermitian(A2))

                                        # matmul for types w/o sizeof (issue #1282)
A = Array(Complex{Int},10,10)
A[:] = complex(1,1)
A2 = A^2
@test A2[1,1] == 20im

                                        # basic tridiagonal operations
n = 5
d = 1 + rand(n)
dl = -rand(n-1)
du = -rand(n-1)
v = randn(n)
B = randn(n,2)
                                        # Woodbury
U = randn(n,2)
V = randn(2,n)
C = randn(2,2)

for elty in (Float32, Float64, Complex64, Complex128)
        d = convert(Vector{elty}, d)
        dl = convert(Vector{elty}, dl)
        du = convert(Vector{elty}, du)
        T = Tridiagonal(dl, d, du)
        @test size(T, 1) == n
        @test size(T) == (n, n)
        F = diagm(d)
        for i = 1:n-1
            F[i,i+1] = du[i]
            F[i+1,i] = dl[i]
        end
        @test full(T) == F
                                        # elementary operations on tridiagonals
        @test conj(T) == Tridiagonal(conj(dl), conj(d), conj(du))
        @test transpose(T) == Tridiagonal(du, d, dl)
        @test ctranspose(T) == Tridiagonal(conj(du), conj(d), conj(dl))
                                        # test interconversion of Tridiagonal and SymTridiagonal
        @test Tridiagonal(dl, d, dl) == SymTridiagonal(d, dl)
        @test Tridiagonal(dl, d, du) + Tridiagonal(du, d, dl) == SymTridiagonal(2d, dl+du)
        @test SymTridiagonal(d, dl) + Tridiagonal(du, d, du) == SymTridiagonal(2d, dl+du)

                                        # tridiagonal linear algebra
        v = convert(Vector{elty}, v)
        @test_approx_eq T*v F*v
        invFv = F\v
        @test_approx_eq T\v invFv
        @test_approx_eq solve(T,v) invFv
        B = convert(Matrix{elty}, B)
        @test_approx_eq solve(T, B) F\B
        Tlu = factorize(T)
        x = Tlu\v
        @test_approx_eq x invFv
        @test_approx_eq det(T) det(F)
                                        # symmetric tridiagonal
        Ts = SymTridiagonal(d, dl)
        Fs = full(Ts)
        invFsv = Fs\v
        Tldlt = ldltd(Ts)
        x = Tldlt\v
        @test_approx_eq x invFsv
                                        # eigenvalues/eigenvectors of symmetric tridiagonal
        if elty === Float32 || elty === Float64
            DT, VT = eig(Ts)
            D, Vecs = eig(Fs)
            @test_approx_eq DT D
            @test_approx_eq abs(VT'Vecs) eye(elty, n)
        end
                                        # Woodbury
        U = convert(Matrix{elty}, U)
        V = convert(Matrix{elty}, V)
        C = convert(Matrix{elty}, C)
        W = Woodbury(T, U, C, V)
        F = full(W)
        @test_approx_eq W*v F*v
        @test_approx_eq W\v F\v
        @test_approx_eq det(W) det(F)

        # Diagonal
        D = Diagonal(d)
        DM = diagm(d)
        @test_approx_eq D*v DM*v
        @test_approx_eq D*U DM*U
        @test_approx_eq D\v DM\v
        @test_approx_eq D\U DM\U
        @test_approx_eq det(D) det(DM)   

        # Test det(A::Matrix)
        # In the long run, these tests should step through Strang's
        #  axiomatic definition of determinants.
        # If all axioms are satisfied and all the composition rules work,
        #  all determinants will be correct except for floating point errors.
     
        # The determinant of the identity matrix should always be 1.
        for i = 1:10
            A = eye(elty, i)
            @test_approx_eq det(A) one(elty)
        end

        # The determinant of a Householder reflection matrix should always be -1.
        for i = 1:10
            A = eye(elty, 10)
            A[i, i] = -one(elty)
            @test_approx_eq det(A) -one(elty)
        end

        # The determinant of a rotation matrix should always be 1.
        for theta = convert(Vector{elty}, pi ./ [1:4])
            R = [cos(theta) -sin(theta);
                 sin(theta) cos(theta)]
            @test_approx_eq convert(elty, det(R)) one(elty)
        end

        # issue 1490
        @test_approx_eq_eps det(ones(elty, 3,3)) zero(elty) 3*eps(real(one(elty)))
end

                                        # LAPACK tests
Ainit = randn(5,5)
for elty in (Float32, Float64, Complex64, Complex128)
                                        # syevr!
        A = convert(Array{elty, 2}, Ainit)
        Asym = A'A
        vals, Z = LinAlg.LAPACK.syevr!('V', copy(Asym))
        @test_approx_eq Z*scale(vals, Z') Asym
        @test all(vals .> 0.0)
        @test_approx_eq LinAlg.LAPACK.syevr!('N','V','U',copy(Asym),0.0,1.0,4,5,-1.0)[1] vals[vals .< 1.0]
        @test_approx_eq LinAlg.LAPACK.syevr!('N','I','U',copy(Asym),0.0,1.0,4,5,-1.0)[1] vals[4:5]
        @test_approx_eq vals LinAlg.LAPACK.syev!('N','U',copy(Asym))
end

#Test equivalence of eigenvectors/singular vectors taking into account possible phase (sign) differences
function test_approx_eq_vecs(a, b)
    n = size(a)[1]
    @test n==size(b)[1]
    elty = typeof(a[1])
    @assert elty==typeof(b[1])
    for i=1:n
        ev1, ev2 = a[:,i], b[:,i]
        deviation = min(abs(norm(ev1-ev2)),abs(norm(ev1+ev2)))
        @test_approx_eq_eps deviation 0.0 n^2*eps(abs(convert(elty, 1.0)))
    end
end

#LAPACK tests for symmetric tridiagonal matrices
n=5
Ainit = randn(n)
Binit = randn(n-1)
for elty in (Float32, Float64)
    A = convert(Array{elty, 1}, Ainit)
    B = convert(Array{elty, 1}, Binit)
    zero, infinity = convert(elty, 0), convert(elty, Inf)
    #This tests eigenvalue and eigenvector computations using stebz! and stein!
    (w, iblock, isplit, info) = LinAlg.LAPACK.stebz!('V','B',-infinity,infinity,0,0,zero,A,B) 

    (evecs, ifail, info)=LinAlg.LAPACK.stein!(A,B,w)
    @test info==0
    @test all(ifail .== 0)
    
    (e, v)=eig(SymTridiagonal(A,B))
    @test_approx_eq e w
    #Take into account possible phase (sign) difference in eigenvectors
    for i=1:n
        ev1 = v[:,i]
        ev2 = evecs[:,i]
        deviation = min(abs(norm(ev1-ev2)),abs(norm(ev1+ev2)))
        @test_approx_eq_eps deviation 0.0 n*eps(abs(convert(elty, 1.0)))
    end

    #Test stein! call using iblock and isplit
    (w, iblock, isplit, info) = LinAlg.LAPACK.stebz!('V','B',-infinity,infinity,0,0,zero,A,B) 
    @test info==0
    (evecs, ifail, info)=LinAlg.LAPACK.stein!(A, B, w, iblock, isplit)
    @test info==0
    @test all(ifail .== 0)
    test_approx_eq_vecs(v, evecs)
end


#Test bidiagonal matrices and their SVDs
dv = randn(n)
ev = randn(n-1)
for elty in (Float32, Float64, Complex64, Complex128)
    if (elty == Complex64)
        dv += im*randn(n)
        ev += im*randn(n-1)
    end
    for isupper in (true, false) #Test upper and lower bidiagonal matrices
        T = Bidiagonal{elty}(dv, ev, isupper)
        
        @test size(T, 1) == n
        @test size(T) == (n, n)
        @test full(T) == diagm(dv) + diagm(ev, isupper?1:-1)
        @test Bidiagonal(full(T), isupper) == T
        z = zeros(elty, n)
                                        # idempotent tests
        @test conj(conj(T)) == T
        @test transpose(transpose(T)) == T
        @test ctranspose(ctranspose(T)) == T

        if (elty <: Real)
            #XXX If I run either of these tests separately, by themselves, things are OK.
            # Enabling BOTH tests results in segfault.
            # Where is the memory corruption???

            @test_approx_eq svdvals(full(T)) svdvals(T)
            u1, d1, v1 = svd(full(T))
            u2, d2, v2 = svd(T)
            @test_approx_eq d1 d2
            test_approx_eq_vecs(u1, u2)
            test_approx_eq_vecs(v1, v2)
        end
    end
end


# Test gglse
for elty in (Float32, Float64, Complex64, Complex128)
    A = convert(Array{elty, 2}, [1 1 1 1; 1 3 1 1; 1 -1 3 1; 1 1 1 3; 1 1 1 -1])
    c = convert(Array{elty, 1}, [2, 1, 6, 3, 1])
    B = convert(Array{elty, 2}, [1 1 1 -1; 1 -1 1 1; 1 1 -1 1])
    d = convert(Array{elty, 1}, [1, 3, -1])
    @test_approx_eq_eps LinAlg.LAPACK.gglse!(A, c, B, d) [0.5, -0.5, 1.5, 0.5] 1e-6
end


## Issue related tests
# issue 1447
let
    A = [1.+0.im 0; 0 1]
    B = pinv(A)
    for i = 1:4
        @test_approx_eq A[i] B[i]
    end
end

# issue 2246
let
    A = [1 2 0 0; 0 1 0 0; 0 0 0 0; 0 0 0 0]
    Asq = sqrtm(A)
    @test_approx_eq Asq*Asq A
    A2 = sub(A, 1:2, 1:2)
    A2sq = sqrtm(A2)
    @test_approx_eq A2sq*A2sq A2
end

let
    N = 3
    @test_approx_eq log(det(eye(N))) logdet(eye(N))
end

# issue 2637
let
  a = [1, 2, 3]
  b = [4, 5, 6]
  @test kron(eye(2),eye(2)) == eye(4)
  @test kron(a,b) == [4,5,6,8,10,12,12,15,18]             
  @test kron(a',b') == [4 5 6 8 10 12 12 15 18]           
  @test kron(a,b')  == [4 5 6; 8 10 12; 12 15 18]         
  @test kron(a',b)  == [4 8 12; 5 10 15; 6 12 18]         
  @test kron(a,eye(2)) == [1 0; 0 1; 2 0; 0 2; 3 0; 0 3]  
  @test kron(eye(2),a) == [ 1 0; 2 0; 3 0; 0 1; 0 2; 0 3] 
  @test kron(eye(2),2) == 2*eye(2)                        
  @test kron(3,eye(3)) == 3*eye(3)                        
  @test kron(a,2) == [2, 4, 6]                            
  @test kron(b',2) == [8 10 12]                              
end
