#include "bls12_381_g1_host.cuh"

namespace libff {

bls12_381_G1_host::bls12_381_G1_host(bls12_381_G1_params_host* params) : params(params), X(params->fq_params), Y(params->fq_params), Z(params->fq_params)
{
    this->X = *params->G1_zero_X;
    this->Y = *params->G1_zero_Y;
    this->Z = *params->G1_zero_Z;
}


void bls12_381_G1_host::to_affine_coordinates()
{
    bls12_381_Fq_host t(params->fq_params);

    if (this->is_zero())
    {
        this->X = t.zero();
        this->Y = t.one();
        this->Z = t.zero();
    }
    else
    {
        bls12_381_Fq_host Z_inv = Z.inverse();
        bls12_381_Fq_host Z2_inv = Z_inv.squared();
        bls12_381_Fq_host Z3_inv = Z2_inv * Z_inv;
        this->X = this->X * Z2_inv;
        this->Y = this->Y * Z3_inv;
        this->Z = t.one();
    }
}

void bls12_381_G1_host::to_special()
{
    this->to_affine_coordinates();
}

bool bls12_381_G1_host::is_special() const
{
    return this->is_zero() || this->Z == this->Z.one();
}

bool bls12_381_G1_host::is_zero() const
{
    return (this->Z.is_zero());
}

bool bls12_381_G1_host::operator==(const bls12_381_G1_host &other) const
{
    if (this->is_zero())
        return other.is_zero();

    if (other.is_zero())
        return false;

    bls12_381_Fq_host Z1_squared = this->Z.squared();
    bls12_381_Fq_host Z2_squared = other.Z.squared();

    if ((this->X * Z2_squared) != (other.X * Z1_squared))
        return false;

    bls12_381_Fq_host Z1_cubed = this->Z * Z1_squared;
    bls12_381_Fq_host Z2_cubed = other.Z * Z2_squared;

    return !((this->Y * Z2_cubed) != (other.Y * Z1_cubed));
}

bool bls12_381_G1_host::operator!=(const bls12_381_G1_host& other) const
{
    return !(operator==(other));
}

bls12_381_G1_host bls12_381_G1_host::operator+(const bls12_381_G1_host &other) const
{
    if (this->is_zero())
        return other;

    if (other.is_zero())
        return *this;

    const bls12_381_Fq_host Z1Z1 = this->Z.squared();
    const bls12_381_Fq_host Z2Z2 = other.Z.squared();

    const bls12_381_Fq_host U1 = this->X * Z2Z2; 
    const bls12_381_Fq_host U2 = other.X * Z1Z1; 

    const bls12_381_Fq_host S1 = this->Y * other.Z * Z2Z2;  // S1 = Y1 * Z2 * Z2Z2
    const bls12_381_Fq_host S2 = this->Z * other.Y * Z1Z1;  // S2 = Y2 * Z1 * Z1Z1

    if (U1 == U2 && S1 == S2)
        return this->dbl(); 

    const bls12_381_Fq_host H = U2 - U1;             // H = U2 - U1
    const bls12_381_Fq_host I = H.dbl().squared();   // I = (2 * H)^2
    const bls12_381_Fq_host J = H * I;               // J = H * I
    const bls12_381_Fq_host r = (S2 - S1).dbl();     // r = 2 * (S2 - S1)
    const bls12_381_Fq_host V = U1 * I;              // V = U1 * I

    const bls12_381_Fq_host X3 = r.squared() - J - V.dbl();                           // X3 = r^2 - J - 2 * V
    const bls12_381_Fq_host Y3 = r * (V - X3)  - (S1 * J).dbl();                      // Y3 = r * (V-X3)-2 * S1 * J
    const bls12_381_Fq_host Z3 = ((this->Z + other.Z).squared() - Z1Z1 - Z2Z2) * H;   // Z3 = ((Z1+Z2)^2-Z1Z1-Z2Z2) * H

    return bls12_381_G1_host(params, X3, Y3, Z3);
}



bls12_381_G1_host bls12_381_G1_host::operator-() const
{
    return bls12_381_G1_host(params, this->X, -(this->Y), this->Z);
}

bls12_381_G1_host bls12_381_G1_host::operator-(const bls12_381_G1_host &other) const
{
    return (*this) + (-other);
}

bls12_381_G1_host bls12_381_G1_host::operator*(const unsigned long lhs) const
{
    return scalar_mul_host<bls12_381_G1_host>(*this, lhs);
}

bls12_381_G1_host bls12_381_G1_host::dbl() const
{
    if (this->is_zero())
        return *this;

    const bls12_381_Fq_host A = this->X.squared();    // A = X1^2
    const bls12_381_Fq_host B = this->Y.squared();    // B = Y1^2
    const bls12_381_Fq_host C = B.squared();          // C = B^2

    const bls12_381_Fq_host D = ((this->X + B).squared() - A - C).dbl();   // D = 2 * ((X1 + B)^2 - A - C)

    const bls12_381_Fq_host E = A + A.dbl();   // E = 3 * A
    const bls12_381_Fq_host F = E.squared();   // F = E^2

    const bls12_381_Fq_host X3 = F - D.dbl();                         // X3 = F - 2 D
    const bls12_381_Fq_host Y3 = E * (D - X3) - C.dbl().dbl().dbl();  // Y3 = E * (D - X3) - 8 * C
    const bls12_381_Fq_host Z3 = (this->Y * this->Z).dbl();           // Z3 = 2 * Y1 * Z1

    return bls12_381_G1_host(params, X3, Y3, Z3);
}


bls12_381_G1_host bls12_381_G1_host::add(const bls12_381_G1_host &other) const
{
    return (*this) + other;
}

bls12_381_G1_host bls12_381_G1_host::mixed_add(const bls12_381_G1_host &other) const
{
    if (this->is_zero())
        return other;

    if (other.is_zero())
        return *this;

    const bls12_381_Fq_host Z1Z1 = this->Z.squared();

    const bls12_381_Fq_host U2 = other.X * Z1Z1;

     const bls12_381_Fq_host S2 = this->Z * other.Y * Z1Z1;   // S2 = Y2 * Z1 * Z1Z1

    if (this->X == U2 && this->Y == S2)
        return this->dbl(); 

    const bls12_381_Fq_host H = U2 - this->X;               // H = U2-X1
    const bls12_381_Fq_host HH = H.squared();               // HH = H^2
    const bls12_381_Fq_host I = HH.dbl().dbl();             // I = 4*HH
    const bls12_381_Fq_host J = H * I;                      // J = H*I
    const bls12_381_Fq_host r = (S2 - this->Y).dbl();       // r = 2*(S2-Y1)
    const bls12_381_Fq_host V = this->X * I;                // V = X1*I
    
    const bls12_381_Fq_host X3 = r.squared() - J - V.dbl();           // X3 = r^2-J-2*V
    const bls12_381_Fq_host Y3 = r * (V - X3) - (this->Y * J).dbl();  // Y3 = r*(V-X3)-2*Y1*J
    const bls12_381_Fq_host Z3 = (this->Z + H).squared() - Z1Z1 - HH; // Z3 = (Z1+H)^2-Z1Z1-HH

    return bls12_381_G1_host(params, X3, Y3, Z3);
}

bool bls12_381_G1_host::is_well_formed() const
{
    if (this->is_zero())
        return true;
    
    bls12_381_Fq_host X2 = this->X.squared();
    bls12_381_Fq_host Y2 = this->Y.squared();
    bls12_381_Fq_host Z2 = this->Z.squared();

    bls12_381_Fq_host X3 = this->X * X2;
    bls12_381_Fq_host Z3 = this->Z * Z2;
    bls12_381_Fq_host Z6 = Z3.squared();

    return (Y2 == X3 + *bls12_381_coeff_b_host * Z6);
}

bls12_381_G1_host bls12_381_G1_host::zero() const
{
    return bls12_381_G1_host(params, *params->G1_zero_X, *params->G1_zero_Y, *params->G1_zero_Z);
}

bls12_381_G1_host bls12_381_G1_host::one() const
{
    return bls12_381_G1_host(params, *params->G1_one_X, *params->G1_one_Y, *params->G1_one_Z);
}

bls12_381_G1_host bls12_381_G1_host::random_element() const
{
    scalar_field t(params->fr_params);
    return (t.random_element().as_bigint()) * this->one();
}


size_t bls12_381_G1_host::size_in_bits()
{
    base_field t(params->fq_params);
    return t.size_in_bits() + 1;
}

bigint_host<bls12_381_q_limbs_host> bls12_381_G1_host::base_field_char()
{
    base_field t(params->fq_params);
    return t.field_char();
}

bigint_host<bls12_381_r_limbs_host> bls12_381_G1_host::order()
{
    scalar_field t(params->fr_params);
    return t.field_char();
}

void bls12_381_G1_host::set_params(bls12_381_G1_params_host* params)
{
    this->params = params;
    this->X.set_params(params->fq_params);
    this->Y.set_params(params->fq_params);
    this->Z.set_params(params->fq_params);
}


}