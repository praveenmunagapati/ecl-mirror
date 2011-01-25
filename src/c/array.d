/* -*- mode: c; c-basic-offset: 8 -*- */
/*
    array.c --  Array routines
*/
/*
    Copyright (c) 1984, Taiichi Yuasa and Masami Hagiya.
    Copyright (c) 1990, Giuseppe Attardi.
    Copyright (c) 2001, Juan Jose Garcia Ripoll.

    ECL is free software; you can redistribute it and/or
    modify it under the terms of the GNU Library General Public
    License as published by the Free Software Foundation; either
    version 2 of the License, or (at your option) any later version.

    See file '../Copyright' for full details.
*/

#include <limits.h>
#include <string.h>
#include <ecl/ecl.h>
#define ECL_DEFINE_AET_SIZE
#include <ecl/internal.h>

static const cl_object ecl_aet_name[] = {
        Ct,                   /* aet_object */
        @'single-float',      /* aet_sf */
        @'double-float',      /* aet_df */
        @'bit',               /* aet_bit: cannot be handled with this code */
        @'ext::cl-fixnum',    /* aet_fix */
        @'ext::cl-index',     /* aet_index */
        @'ext::byte8',        /* aet_b8 */
        @'ext::integer8',     /* aet_i8 */
#ifdef ecl_uint16_t
        @'ext::byte16',
        @'ext::integer16',
#endif
#ifdef ecl_uint32_t
        @'ext::byte32',
        @'ext::integer32',
#endif
#ifdef ecl_uint64_t
        @'ext::byte64',
        @'ext::integer64',
#endif
#ifdef ECL_UNICODE
        @'character',         /* aet_ch */
#endif
        @'base-char'          /* aet_bc */
};

static void check_displaced (cl_object dlist, cl_object orig, cl_index newdim);

static void FEbad_aet() ecl_attr_noreturn;

static void
FEbad_aet()
{
	FEerror(
"A routine from ECL got an object with a bad array element type.\n"
"If you are running a standard copy of ECL, please report this bug.\n"
"If you are embedding ECL into an application, please ensure you\n"
"passed the right value to the array creation routines.\n",0);
}

static cl_index
out_of_bounds_error(cl_index ndx, cl_object x)
{
	cl_object type = cl_list(3, @'integer', MAKE_FIXNUM(0),
                                 MAKE_FIXNUM(x->array.dim));
        FEwrong_type_argument(ecl_make_integer(ndx), type);
}

void
FEwrong_dimensions(cl_object a, cl_index rank)
{
        cl_object list = cl_make_list(3, MAKE_FIXNUM(rank),
                                      @':initial-element', @'*');
        cl_object type = cl_list(3, @'array', @'*', list);
        FEwrong_type_argument(type, a);
}

static ECL_INLINE cl_index
checked_index(cl_object function, cl_object a, int which, cl_object index,
              cl_index nonincl_limit)
{
        cl_index output;
        if (ecl_unlikely(!ECL_FIXNUMP(index) || ecl_fixnum_minusp(index)))
                FEwrong_index(function, a, which, index, nonincl_limit);
        output = fix(index);
        if (ecl_unlikely(output >= nonincl_limit))
                FEwrong_index(function, a, which, index, nonincl_limit);
        return output;
}

cl_index
ecl_to_index(cl_object n)
{
	switch (type_of(n)) {
	case t_fixnum: {
		cl_fixnum out = fix(n);
		if (out < 0 || out >= ADIMLIM)
			FEtype_error_index(Cnil, n);
		return out;
	}
	case t_bignum:
		FEtype_error_index(Cnil, n);
	default:
                FEwrong_type_only_arg(@[coerce], n, @[integer]);
	}
}

cl_object
cl_row_major_aref(cl_object x, cl_object indx)
{
	cl_index j = fixnnint(indx);
	@(return ecl_aref(x, j))
}

cl_object
si_row_major_aset(cl_object x, cl_object indx, cl_object val)
{
	cl_index j = fixnnint(indx);
	@(return ecl_aset(x, j, val))
}

@(defun aref (x &rest indx)
@ {
	cl_index i, j;
	cl_index r = narg - 1;
	switch (type_of(x)) {
	case t_array:
		if (r != x->array.rank)
			FEerror("Wrong number of indices.", 0);
		for (i = j = 0;  i < r;  i++) {
			cl_index s = checked_index(@[aref], x, i,
                                                   cl_va_arg(indx),
                                                   x->array.dims[i]);
			j = j*(x->array.dims[i]) + s;
		}
		break;
	case t_vector:
#ifdef ECL_UNICODE
	case t_string:
#endif
	case t_base_string:
	case t_bitvector:
		if (r != 1)
			FEerror("Wrong number of indices.", 0);
		j = checked_index(@[aref], x, -1, cl_va_arg(indx), x->vector.dim);
		break;
	default:
                FEwrong_type_nth_arg(@[aref], 1, x, @[array]);
	}
	@(return ecl_aref_unsafe(x, j));
} @)

cl_object
ecl_aref_unsafe(cl_object x, cl_index index)
{
	switch (x->array.elttype) {
	case aet_object:
		return x->array.self.t[index];
	case aet_bc:
		return CODE_CHAR(x->base_string.self[index]);
#ifdef ECL_UNICODE
	case aet_ch:
                return CODE_CHAR(x->string.self[index]);
#endif
	case aet_bit:
		index += x->vector.offset;
		if (x->vector.self.bit[index/CHAR_BIT] & (0200>>index%CHAR_BIT))
			return(MAKE_FIXNUM(1));
		else
			return(MAKE_FIXNUM(0));
	case aet_fix:
		return ecl_make_integer(x->array.self.fix[index]);
	case aet_index:
		return ecl_make_unsigned_integer(x->array.self.index[index]);
	case aet_sf:
		return(ecl_make_singlefloat(x->array.self.sf[index]));
	case aet_df:
		return(ecl_make_doublefloat(x->array.self.df[index]));
	case aet_b8:
		return ecl_make_uint8_t(x->array.self.b8[index]);
	case aet_i8:
		return ecl_make_int8_t(x->array.self.i8[index]);
#ifdef ecl_uint16_t
	case aet_b16:
		return ecl_make_uint16_t(x->array.self.b16[index]);
	case aet_i16:
		return ecl_make_int16_t(x->array.self.i16[index]);
#endif
#ifdef ecl_uint32_t
	case aet_b32:
		return ecl_make_uint32_t(x->array.self.b32[index]);
	case aet_i32:
		return ecl_make_int32_t(x->array.self.i32[index]);
#endif
#ifdef ecl_uint64_t
	case aet_b64:
		return ecl_make_uint64_t(x->array.self.b64[index]);
	case aet_i64:
		return ecl_make_int64_t(x->array.self.i64[index]);
#endif
	default:
		FEbad_aet();
	}
}

cl_object
ecl_aref(cl_object x, cl_index index)
{
        if (ecl_unlikely(!ECL_ARRAYP(x))) {
                FEwrong_type_nth_arg(@[aref], 1, x, @[array]);
        }
        if (ecl_unlikely(index >= x->array.dim)) {
                FEwrong_index(@[row-major-aref], x, -1, MAKE_FIXNUM(index),
                              x->array.dim);
        }
        return ecl_aref_unsafe(x, index);
}

cl_object
ecl_aref1(cl_object x, cl_index index)
{
        if (ecl_unlikely(!ECL_VECTORP(x))) {
                FEwrong_type_nth_arg(@[aref], 1, x, @[array]);
        }
        if (ecl_unlikely(index >= x->array.dim)) {
                FEwrong_index(@[aref], x, -1, MAKE_FIXNUM(index),
                              x->array.dim);
        }
        return ecl_aref_unsafe(x, index);
}

void *
ecl_row_major_ptr(cl_object x, cl_index index, cl_index bytes)
{
	cl_index idx, elt_size, offset;
	cl_elttype elt_type;

	if (ecl_unlikely(!ECL_ARRAYP(x))) {
		FEwrong_type_nth_arg(@[aref], 1, x, @[array]);
	}

	elt_type = x->array.elttype;
	if (ecl_unlikely(elt_type == aet_bit || elt_type == aet_object))
		FEerror("In ecl_row_major_ptr: Specialized array expected, element type ~S found.",
			1,ecl_elttype_to_symbol(elt_type));

	elt_size = ecl_aet_size[elt_type];
	offset = index*elt_size;

	/* don't check bounds if bytes == 0 */
        if (ecl_unlikely(bytes > 0 && offset + bytes > x->array.dim*elt_size)) {
                FEwrong_index(@[row-major-aref], x, -1, MAKE_FIXNUM(index),
                              x->array.dim);
        }

	return x->array.self.b8 + offset;
}

/*
	Internal function for setting array elements:

		(si:aset value array dim0 ... dimN)
*/
@(defun si::aset (x &rest dims)
@ {
	cl_index i, j;
	cl_index r = narg - 2;
	cl_object v;
	switch (type_of(x)) {
	case t_array:
		if (ecl_unlikely(r != x->array.rank))
			FEerror("Wrong number of indices.", 0);
		for (i = j = 0;  i < r;  i++) {
			cl_index s = checked_index(@[si::aset], x, i,
                                                   cl_va_arg(dims),
                                                   x->array.dims[i]);
			j = j*(x->array.dims[i]) + s;
		}
		break;
	case t_vector:
#ifdef ECL_UNICODE
	case t_string:
#endif
	case t_base_string:
	case t_bitvector:
		if (ecl_unlikely(r != 1))
			FEerror("Wrong number of indices.", 0);
		j = checked_index(@[si::aset], x, -1, cl_va_arg(dims),
                                  x->vector.dim);
		break;
	default:
                FEwrong_type_nth_arg(@[si::aset], 1, x, @[array]);
	}
	v = cl_va_arg(dims);
	@(return ecl_aset_unsafe(x, j, v))
} @)

cl_object
ecl_aset_unsafe(cl_object x, cl_index index, cl_object value)
{
	switch (x->array.elttype) {
	case aet_object:
		x->array.self.t[index] = value;
		break;
	case aet_bc:
		/* INV: ecl_char_code() checks the type of `value' */
		x->base_string.self[index] = ecl_char_code(value);
		break;
#ifdef ECL_UNICODE
	case aet_ch:
		x->string.self[index] = ecl_char_code(value);
		break;
#endif
	case aet_bit: {
		cl_fixnum i = ecl_to_bit(value);
		index += x->vector.offset;
		if (i == 0)
			x->vector.self.bit[index/CHAR_BIT] &= ~(0200>>index%CHAR_BIT);
		else
			x->vector.self.bit[index/CHAR_BIT] |= 0200>>index%CHAR_BIT;
		break;
	}
	case aet_fix:
		x->array.self.fix[index] = fixint(value);
		break;
	case aet_index:
		x->array.self.index[index] = fixnnint(value);
		break;
	case aet_sf:
		x->array.self.sf[index] = ecl_to_float(value);
		break;
	case aet_df:
		x->array.self.df[index] = ecl_to_double(value);
		break;
	case aet_b8:
		x->array.self.b8[index] = ecl_to_uint8_t(value);
		break;
	case aet_i8:
		x->array.self.i8[index] = ecl_to_int8_t(value);
		break;
#ifdef ecl_uint16_t
	case aet_b16:
		x->array.self.b16[index] = ecl_to_uint16_t(value);
		break;
	case aet_i16:
		x->array.self.i16[index] = ecl_to_int16_t(value);
		break;
#endif
#ifdef ecl_uint32_t
	case aet_b32:
		x->array.self.b32[index] = ecl_to_uint32_t(value);
		break;
	case aet_i32:
		x->array.self.i32[index] = ecl_to_int32_t(value);
		break;
#endif
#ifdef ecl_uint64_t
	case aet_b64:
		x->array.self.b64[index] = ecl_to_uint64_t(value);
		break;
	case aet_i64:
		x->array.self.i64[index] = ecl_to_int64_t(value);
		break;
#endif
	}
	return(value);
}

cl_object
ecl_aset(cl_object x, cl_index index, cl_object value)
{
        if (ecl_unlikely(!ECL_ARRAYP(x))) {
                FEwrong_type_nth_arg(@[si::aset], 1, x, @[array]);
        }
        if (ecl_unlikely(index >= x->array.dim)) {
		out_of_bounds_error(index, x);
        }
        return ecl_aset_unsafe(x, index, value);
}

cl_object
ecl_aset1(cl_object x, cl_index index, cl_object value)
{
        if (ecl_unlikely(!ECL_VECTORP(x))) {
                FEwrong_type_nth_arg(@[si::aset], 1, x, @[array]);
        }
        if (ecl_unlikely(index >= x->array.dim)) {
		out_of_bounds_error(index, x);
        }
        return ecl_aset_unsafe(x, index, value);
}

/*
	Internal function for making arrays of more than one dimension:

		(si:make-pure-array dimension-list element-type adjustable
			            displaced-to displaced-index-offset)
*/
cl_object
si_make_pure_array(cl_object etype, cl_object dims, cl_object adj,
		   cl_object fillp, cl_object displ, cl_object disploff)
{
	cl_index r, s, i, j;
	cl_object x;
	if (FIXNUMP(dims)) {
		return si_make_vector(etype, dims, adj, fillp, displ, disploff);
	} else if (ecl_unlikely(!ECL_LISTP(dims))) {
                FEwrong_type_nth_arg(@[make-array], 1, dims,
                                     cl_list(3, @'or', @'list', @'fixnum'));
        }
	r = ecl_length(dims);
	if (ecl_unlikely(r >= ARANKLIM)) {
		FEerror("The array rank, ~R, is too large.", 1, MAKE_FIXNUM(r));
	} else if (r == 1) {
		return si_make_vector(etype, ECL_CONS_CAR(dims), adj, fillp,
				      displ, disploff);
	} else if (ecl_unlikely(!Null(fillp))) {
		FEerror(":FILL-POINTER may not be specified for an array of rank ~D",
			1, MAKE_FIXNUM(r));
	}
	x = ecl_alloc_object(t_array);
	x->array.displaced = Cnil;
	x->array.self.t = NULL;		/* for GC sake */
	x->array.rank = r;
	x->array.elttype = (short)ecl_symbol_to_elttype(etype);
	x->array.flags = 0; /* no fill pointer, no adjustable */
	x->array.dims = (cl_index *)ecl_alloc_atomic_align(sizeof(cl_index)*r, sizeof(cl_index));
	for (i = 0, s = 1;  i < r;  i++, dims = ECL_CONS_CDR(dims)) {
                cl_object d = ECL_CONS_CAR(dims);
                if (ecl_unlikely(!ECL_FIXNUMP(d) ||
                                 ecl_fixnum_minusp(d) ||
                                 ecl_fixnum_greater(d, MAKE_FIXNUM(ADIMLIM))))
                {
                        cl_object type = ecl_make_integer_type(MAKE_FIXNUM(0),
                                                               MAKE_FIXNUM(ADIMLIM));
                        FEwrong_type_nth_arg(@[make-array], 1, d, type);
                }
                j = fix(d);
		s *= (x->array.dims[i] = j);
		if (ecl_unlikely(s > ATOTLIM)) {
                        cl_object type = ecl_make_integer_type(MAKE_FIXNUM(0),
                                                               MAKE_FIXNUM(ATOTLIM));
                        FEwrong_type_key_arg(@[make-array], @[array-total-size],
                                             MAKE_FIXNUM(s), type);
                }
	}
	x->array.dim = s;
        if (adj != Cnil) {
                x->array.flags |= ECL_FLAG_ADJUSTABLE;
        }
	if (Null(displ))
		ecl_array_allocself(x);
	else
		ecl_displace(x, displ, disploff);
	@(return x);
}

/*
	Internal function for making vectors:

		(si:make-vector element-type dimension adjustable fill-pointer
				displaced-to displaced-index-offset)
*/
cl_object
si_make_vector(cl_object etype, cl_object dim, cl_object adj,
	       cl_object fillp, cl_object displ, cl_object disploff)
{
	cl_index d, f;
	cl_object x;
	cl_elttype aet;
 AGAIN:
	aet = ecl_symbol_to_elttype(etype);
        if (ecl_unlikely(!ECL_FIXNUMP(dim) || ecl_fixnum_minusp(dim) ||
                         ecl_fixnum_greater(dim, ADIMLIM))) {
                cl_object type = ecl_make_integer_type(MAKE_FIXNUM(0),
                                                       MAKE_FIXNUM(ADIMLIM));
                FEwrong_type_nth_arg(@[make-array], 1, dim, type);
        }
        d = fix(dim);
	if (aet == aet_bc) {
		x = ecl_alloc_object(t_base_string);
                x->base_string.elttype = (short)aet;
	} else if (aet == aet_bit) {
		x = ecl_alloc_object(t_bitvector);
                x->vector.elttype = (short)aet;
#ifdef ECL_UNICODE
	} else if (aet == aet_ch) {
		x = ecl_alloc_object(t_string);
                x->string.elttype = (short)aet;
#endif
	} else {
		x = ecl_alloc_object(t_vector);
		x->vector.elttype = (short)aet;
	}
	x->vector.self.t = NULL;		/* for GC sake */
	x->vector.displaced = Cnil;
	x->vector.dim = d;
        x->vector.flags = 0;
        if (adj != Cnil) {
                x->vector.flags |= ECL_FLAG_ADJUSTABLE;
        }
	if (Null(fillp)) {
		f = d;
	} else if (fillp == Ct) {
		x->vector.flags |= ECL_FLAG_HAS_FILL_POINTER;
		f = d;
	} else if (FIXNUMP(fillp) && ((f = fix(fillp)) <= d) && (f >= 0)) {
		x->vector.flags |= ECL_FLAG_HAS_FILL_POINTER;
	} else {
		fillp = ecl_type_error(@'make-array',"fill pointer",fillp,
				       cl_list(3,@'or',cl_list(3,@'member',Cnil,Ct),
					       cl_list(3,@'integer',MAKE_FIXNUM(0),
						       dim)));
		goto AGAIN;
	}
	x->vector.fillp = f;

	if (Null(displ))
		ecl_array_allocself(x);
	else
		ecl_displace(x, displ, disploff);
	@(return x)
}

cl_object *
alloc_pointerfull_memory(cl_index l)
{
        cl_object *p = ecl_alloc_align(sizeof(cl_object) * l, sizeof(cl_object));
        cl_index i;
        for (i = 0; l--;)
                p[i++] = Cnil;
        return p;
}

void
ecl_array_allocself(cl_object x)
{
        cl_elttype t = x->array.elttype;
	cl_index i, d = x->array.dim;
	switch (t) {
	/* assign self field only after it has been filled, for GC sake  */
	case aet_object:
		x->array.self.t = alloc_pointerfull_memory(d);
		return;
#ifdef ECL_UNICODE
	case aet_ch: {
		ecl_character *elts;
                d *= sizeof(ecl_character);
		elts = (ecl_character *)ecl_alloc_atomic_align(d, sizeof(ecl_character));
		x->string.self = elts;
		return;
        }
#endif
        case aet_bit:
                d = (d + (CHAR_BIT-1)) / CHAR_BIT;
                x->vector.self.bit = (byte *)ecl_alloc_atomic(d);
                x->vector.offset = 0;
                break;
        default: {
                cl_index elt_size = ecl_aet_size[t];
                d *= elt_size;
                x->vector.self.bc = (ecl_base_char *)ecl_alloc_atomic_align(d, elt_size);
        }
        }
}

cl_object
ecl_alloc_simple_vector(cl_index l, cl_elttype aet)
{
	cl_object x;

	switch (aet) {
	case aet_bc:
                x = ecl_alloc_compact_object(t_base_string, l+1);
                x->base_string.self = ECL_COMPACT_OBJECT_EXTRA(x);
                memset(x->base_string.self, 0, l+1);
                break;
#ifdef ECL_UNICODE
	case aet_ch:
                {
                cl_index bytes = sizeof(ecl_character) * l;
                x = ecl_alloc_compact_object(t_string, bytes);
                x->string.self = ECL_COMPACT_OBJECT_EXTRA(x);
                }
                break;
#endif
	case aet_bit:
                {
                cl_index bytes = (l + (CHAR_BIT-1))/CHAR_BIT;
                x = ecl_alloc_compact_object(t_bitvector, bytes);
                x->vector.self.bit = ECL_COMPACT_OBJECT_EXTRA(x);
		x->vector.offset = 0;
                }
		break;
        case aet_object:
                {
		x = ecl_alloc_object(t_vector);
                x->vector.self.t = alloc_pointerfull_memory(l);
                }
                break;
	default:
		x = ecl_alloc_compact_object(t_vector, l * ecl_aet_size[aet]);
                x->vector.self.bc = ECL_COMPACT_OBJECT_EXTRA(x);
	}
        x->base_string.elttype = aet;
        x->base_string.flags = 0; /* no fill pointer, not adjustable */
        x->base_string.displaced = Cnil;
        x->base_string.dim = x->base_string.fillp = l;
	return x;
}

cl_elttype
ecl_symbol_to_elttype(cl_object x)
{
 BEGIN:
	if (x == @'base-char')
		return(aet_bc);
#ifdef ECL_UNICODE
	if (x == @'character')
		return(aet_ch);
#endif
	else if (x == @'bit')
		return(aet_bit);
	else if (x == @'ext::cl-fixnum')
		return(aet_fix);
	else if (x == @'ext::cl-index')
		return(aet_index);
	else if (x == @'single-float' || x == @'short-float')
		return(aet_sf);
	else if (x == @'double-float')
		return(aet_df);
	else if (x == @'long-float') {
#ifdef ECL_LONG_FLOAT
		return(aet_object);
#else
		return(aet_df);
#endif
	} else if (x == @'ext::byte8')
		return(aet_b8);
	else if (x == @'ext::integer8')
		return(aet_i8);
#ifdef ecl_uint16_t
	else if (x == @'ext::byte16')
		return(aet_b16);
	else if (x == @'ext::integer16')
		return(aet_i16);
#endif
#ifdef ecl_uint32_t
	else if (x == @'ext::byte32')
		return(aet_b32);
	else if (x == @'ext::integer32')
		return(aet_i32);
#endif
#ifdef ecl_uint64_t
	else if (x == @'ext::byte64')
		return(aet_b64);
	else if (x == @'ext::integer64')
		return(aet_i64);
#endif
	else if (x == @'t')
		return(aet_object);
	else if (x == Cnil) {
		FEerror("ECL does not support arrays with element type NIL", 0);
	}
	x = cl_upgraded_array_element_type(1, x);
	goto BEGIN;
}

cl_object
ecl_elttype_to_symbol(cl_elttype aet)
{
        return ecl_aet_name[aet];
}

cl_object
si_array_element_type_byte_size(cl_object type) {
        cl_elttype aet = ECL_ARRAYP(type) ?
                type->array.elttype :
                ecl_symbol_to_elttype(type);
	cl_object size = MAKE_FIXNUM(ecl_aet_size[aet]);
	if (aet == aet_bit)
		size = ecl_make_ratio(MAKE_FIXNUM(1),MAKE_FIXNUM(CHAR_BIT));
	@(return size ecl_elttype_to_symbol(aet))
}

static void *
address_inc(void *address, cl_fixnum inc, cl_elttype elt_type)
{
	union ecl_array_data aux;
	aux.t = address;
	switch (elt_type) {
	case aet_object:
		return aux.t + inc;
	case aet_fix:
		return aux.fix + inc;
	case aet_index:
		return aux.fix + inc;
	case aet_sf:
		return aux.sf + inc;
	case aet_bc:
		return aux.bc + inc;
#ifdef ECL_UNICODE
	case aet_ch:
                return aux.c + inc;
#endif
	case aet_df:
		return aux.df + inc;
	case aet_b8:
	case aet_i8:
		return aux.b8 + inc;
#ifdef ecl_uint16_t
	case aet_b16:
	case aet_i16:
		return aux.b16 + inc;
#endif
#ifdef ecl_uint32_t
	case aet_b32:
	case aet_i32:
		return aux.b32 + inc;
#endif
#ifdef ecl_uint64_t
	case aet_b64:
	case aet_i64:
		return aux.b64 + inc;
#endif
	default:
		FEbad_aet();
	}
}

static void *
array_address(cl_object x, cl_index inc)
{
	return address_inc(x->array.self.t, inc, x->array.elttype);
}

cl_object
cl_array_element_type(cl_object a)
{
	@(return ecl_elttype_to_symbol(ecl_array_elttype(a)))
}

/*
	Displace(from, to, offset) displaces the from-array
	to the to-array (the original array) by the specified offset.
	It changes the a_displaced field of both arrays.
	The field is a cons; the car of the from-array points to
	the to-array and the cdr of the to-array is a list of arrays
	displaced to the to-array, so the from-array is pushed to the
	cdr of the to-array's array.displaced.
*/
void
ecl_displace(cl_object from, cl_object to, cl_object offset)
{
	cl_index j;
	void *base;
	cl_elttype totype, fromtype;
	fromtype = from->array.elttype;
        if (ecl_unlikely(!ECL_FIXNUMP(offset) || ((j = fix(offset)) < 0))) {
                FEwrong_type_key_arg(@[adjust-array], @[:displaced-index-offset],
                                     offset, @[fixnum]);
        }
	if (type_of(to) == t_foreign) {
		if (fromtype == aet_bit || fromtype == aet_object) {
			FEerror("Cannot displace arrays with element type T or BIT onto foreign data",0);
		}
		base = to->foreign.data;
		from->array.displaced = to;
	} else {
                cl_fixnum maxdim;
		totype = to->array.elttype;
		if (totype != fromtype)
			FEerror("Cannot displace the array, "
                                "because the element types don't match.", 0);
                maxdim = to->array.dim - from->array.dim;
		if (maxdim < 0)
			FEerror("Cannot displace the array, "
                                "because the total size of the to-array"
                                "is too small.", 0);
                if (j > maxdim) {
                        cl_object type = ecl_make_integer_type(MAKE_FIXNUM(0),
                                                               MAKE_FIXNUM(maxdim));
                        FEwrong_type_key_arg(@[adjust-array], @[:displaced-index-offset],
                                             offset, type);
                }
		from->array.displaced = ecl_list1(to);
		if (Null(to->array.displaced))
			to->array.displaced = ecl_list1(Cnil);
		ECL_RPLACD(to->array.displaced, CONS(from, CDR(to->array.displaced)));
		if (fromtype == aet_bit) {
			j += to->vector.offset;
			from->vector.offset = j%CHAR_BIT;
			from->vector.self.bit = to->vector.self.bit + j/CHAR_BIT;
			return;
		}
		base = to->array.self.t;
	}
	from->array.self.t = address_inc(base, j, fromtype);
}

cl_object
si_array_raw_data(cl_object x)
{
        cl_elttype et = ecl_array_elttype(x);
        cl_index total_size = x->vector.dim * ecl_aet_size[et];
        cl_object output, to_array;
        uint8_t *data;
        if (et == aet_object) {
                FEerror("EXT:ARRAY-RAW-DATA can not get data "
                        "from an array with element type T.", 0);
        }
        data = x->vector.self.b8;
        to_array = x->array.displaced;
        if (to_array == Cnil || ((to_array = ECL_CONS_CAR(to_array)) == Cnil)) {
                output = ecl_alloc_object(t_vector);
                output->vector.elttype = aet_b8;
                output->vector.self.b8 = data;
                output->vector.dim = output->vector.fillp = total_size;
                output->vector.flags = 0; /* no fill pointer, not adjustable */
                output->vector.displaced = Cnil;
        } else {
                cl_index displ = data - to_array->vector.self.b8;
                output = si_make_vector(@'ext::byte8',
                                        MAKE_FIXNUM(total_size),
                                        Cnil,
                                        Cnil,
                                        si_array_raw_data(to_array),
                                        MAKE_FIXNUM(displ));
        }
        @(return output)
}

cl_elttype
ecl_array_elttype(cl_object x)
{
        if (ecl_unlikely(!ECL_ARRAYP(x)))
                FEwrong_type_argument(@[array], x);
        return x->array.elttype;
}

cl_object
cl_array_rank(cl_object a)
{
        if (ecl_unlikely(!ECL_ARRAYP(a)))
                FEwrong_type_only_arg(@[array-rank], a, @[array]);
	@(return ((type_of(a) == t_array) ? MAKE_FIXNUM(a->array.rank)
					  : MAKE_FIXNUM(1)))
}

cl_object
cl_array_dimension(cl_object a, cl_object index)
{
	@(return MAKE_FIXNUM(ecl_array_dimension(a, fixnnint(index))))
}

cl_index
ecl_array_dimension(cl_object a, cl_index index)
{
	switch (type_of(a)) {
	case t_array: {
                if (ecl_unlikely(index > a->array.rank))
                        FEwrong_dimensions(a, index+1);
		return a->array.dims[index];
	}
#ifdef ECL_UNICODE
	case t_string:
#endif
	case t_base_string:
	case t_vector:
	case t_bitvector:
                if (ecl_unlikely(index))
                        FEwrong_dimensions(a, index+1);
		return a->vector.dim;
	default:
                FEwrong_type_only_arg(@[array-dimension], a, @[array]);
	}
}

cl_object
cl_array_total_size(cl_object a)
{
        if (ecl_unlikely(!ECL_ARRAYP(a)))
                FEwrong_type_only_arg(@[array-total-size], a, @[array]);
	@(return MAKE_FIXNUM(a->array.dim))
}

cl_object
cl_adjustable_array_p(cl_object a)
{
        if (ecl_unlikely(!ECL_ARRAYP(a)))
                FEwrong_type_only_arg(@[adjustable-array-p], a, @[array]);
	@(return (ECL_ADJUSTABLE_ARRAY_P(a) ? Ct : Cnil))
}

/*
	Internal function for checking if an array is displaced.
*/
cl_object
cl_array_displacement(cl_object a)
{
	const cl_env_ptr the_env = ecl_process_env();
	cl_object to_array;
	cl_index offset;

        if (ecl_unlikely(!ECL_ARRAYP(a)))
                FEwrong_type_only_arg(@[array-displacement], a, @[array]);
	to_array = a->array.displaced;
	if (Null(to_array)) {
		offset = 0;
	} else if (Null(to_array = CAR(a->array.displaced))) {
		offset = 0;
	} else {
		switch (a->array.elttype) {
		case aet_object:
			offset = a->array.self.t - to_array->array.self.t;
			break;
		case aet_bc:
			offset = a->array.self.bc - to_array->array.self.bc;
			break;
#ifdef ECL_UNICODE
		case aet_ch:
			offset = a->array.self.c - to_array->array.self.c;
			break;
#endif
		case aet_bit:
			offset = a->array.self.bit - to_array->array.self.bit;
			offset = offset * CHAR_BIT + a->array.offset
				- to_array->array.offset;
			break;
		case aet_fix:
			offset = a->array.self.fix - to_array->array.self.fix;
			break;
		case aet_index:
			offset = a->array.self.fix - to_array->array.self.fix;
			break;
		case aet_sf:
			offset = a->array.self.sf - to_array->array.self.sf;
			break;
		case aet_df:
			offset = a->array.self.df - to_array->array.self.df;
			break;
		case aet_b8:
		case aet_i8:
			offset = a->array.self.b8 - to_array->array.self.b8;
			break;
#ifdef ecl_uint16_t
		case aet_b16:
		case aet_i16:
			offset = a->array.self.b16 - to_array->array.self.b16;
			break;
#endif
#ifdef ecl_uint32_t
		case aet_b32:
		case aet_i32:
			offset = a->array.self.b32 - to_array->array.self.b32;
			break;
#endif
#ifdef ecl_uint64_t
		case aet_b64:
		case aet_i64:
			offset = a->array.self.b64 - to_array->array.self.b64;
			break;
#endif
		default:
			FEbad_aet();
		}
	}
	@(return to_array MAKE_FIXNUM(offset));
}

cl_object
cl_svref(cl_object x, cl_object index)
{
	const cl_env_ptr the_env = ecl_process_env();
	cl_index i;

	if (ecl_unlikely(type_of(x) != t_vector ||
                         (x->vector.flags & (ECL_FLAG_ADJUSTABLE | ECL_FLAG_HAS_FILL_POINTER)) ||
                         CAR(x->vector.displaced) != Cnil ||
                         (cl_elttype)x->vector.elttype != aet_object))
	{
                FEwrong_type_nth_arg(@[svref],1,x,@[simple-vector]);
	}
        i = checked_index(@[svref], x, -1, index, x->vector.dim);
	@(return x->vector.self.t[i])
}

cl_object
si_svset(cl_object x, cl_object index, cl_object v)
{
	const cl_env_ptr the_env = ecl_process_env();
	cl_index i;

	if (ecl_unlikely(type_of(x) != t_vector ||
                         (x->vector.flags & (ECL_FLAG_ADJUSTABLE | ECL_FLAG_HAS_FILL_POINTER)) ||
                         CAR(x->vector.displaced) != Cnil ||
                         (cl_elttype)x->vector.elttype != aet_object))
	{
		FEwrong_type_nth_arg(@[si::svset],1,x,@[simple-vector]);
	}
        i = checked_index(@[svref], x, -1, index, x->vector.dim);
	@(return (x->vector.self.t[i] = v))
}

cl_object
cl_array_has_fill_pointer_p(cl_object a)
{
	const cl_env_ptr the_env = ecl_process_env();
	cl_object r;
	switch (type_of(a)) {
	case t_array:
		r = Cnil; break;
	case t_vector:
	case t_bitvector:
#ifdef ECL_UNICODE
	case t_string:
#endif
	case t_base_string:
		r = ECL_ARRAY_HAS_FILL_POINTER_P(a)? Ct : Cnil;
		break;
	default:
                FEwrong_type_nth_arg(@[array-has-fill-pointer-p],1,a,@[array]);
	}
	@(return r)
}

cl_object
cl_fill_pointer(cl_object a)
{
	const cl_env_ptr the_env = ecl_process_env();
        if (ecl_unlikely(!ECL_VECTORP(a)))
                FEwrong_type_only_arg(@[fill-pointer], a, @[vector]);
	if (ecl_unlikely(!ECL_ARRAY_HAS_FILL_POINTER_P(a))) {
                const char *type = "(AND VECTOR (SATISFIES ARRAY-HAS-FILL-POINTER-P))";
		FEwrong_type_nth_arg(@[fill-pointer], 1, a, ecl_read_from_cstring(type));
	}
	@(return MAKE_FIXNUM(a->vector.fillp))
}

/*
	Internal function for setting fill pointer.
*/
cl_object
si_fill_pointer_set(cl_object a, cl_object fp)
{
	const cl_env_ptr the_env = ecl_process_env();
        cl_fixnum i;
        if (ecl_unlikely(!ECL_VECTORP(a) || !ECL_ARRAY_HAS_FILL_POINTER_P(a))) {
                const char *type = "(AND VECTOR (SATISFIES ARRAY-HAS-FILL-POINTER-P))";
		FEwrong_type_nth_arg(@[adjust-array], 1, a,
                                     ecl_read_from_cstring(type));
        }
        if (ecl_unlikely(!ECL_FIXNUMP(fp) || ((i = fix(fp)) < 0) ||
                         (i > a->vector.dim))) {
                cl_object type = ecl_make_integer_type(MAKE_FIXNUM(0),
                                                       MAKE_FIXNUM(a->vector.dim-1));
                FEwrong_type_key_arg(@[adjust-array], @[:fill-pointer], fp, type);
        }
        a->vector.fillp = i;
	@(return fp)
}

/*
	Internal function for replacing the contents of arrays:

		(si:replace-array old-array new-array).

	Used in ADJUST-ARRAY.
*/
cl_object
si_replace_array(cl_object olda, cl_object newa)
{
	const cl_env_ptr the_env = ecl_process_env();
	cl_object dlist;
	if (type_of(olda) != type_of(newa)
	    || (type_of(olda) == t_array && olda->array.rank != newa->array.rank))
		goto CANNOT;
	if (!ECL_ADJUSTABLE_ARRAY_P(olda)) {
		/* When an array is not adjustable, we simply output the new array */
		olda = newa;
		goto OUTPUT;
	}
	for (dlist = CDR(olda->array.displaced); dlist != Cnil; dlist = CDR(dlist)) {
		cl_object other_array = CAR(dlist);
		cl_object offset;
		cl_array_displacement(other_array);
		offset = VALUES(1);
		ecl_displace(other_array, newa, offset);
	}
	switch (type_of(olda)) {
	case t_array:
	case t_vector:
	case t_bitvector:
		olda->array = newa->array;
		break;
#ifdef ECL_UNICODE
	case t_string:
#endif
	case t_base_string:
		olda->base_string = newa->base_string;
		break;
	default:
	CANNOT:
		FEerror("Cannot replace the array ~S by the array ~S.",
			2, olda, newa);
	}
 OUTPUT:
	@(return olda)
}

void
ecl_copy_subarray(cl_object dest, cl_index i0, cl_object orig,
		  cl_index i1, cl_index l)
{
	cl_elttype t = ecl_array_elttype(dest);
	if (i0 + l > dest->array.dim) {
		l = dest->array.dim - i0;
	}
	if (i1 + l > orig->array.dim) {
		l = orig->array.dim - i1;
	}
        if (dest == orig && i0 > i1) {
                if (t != ecl_array_elttype(orig) || t == aet_bit) {
                        for (i0 += l, i1 += l; l--; ) {
                                ecl_aset_unsafe(dest, --i0,
                                                ecl_aref_unsafe(orig, --i1));
                        }
                } else {
                        cl_index elt_size = ecl_aet_size[t];
                        memmove(dest->array.self.bc + i0 * elt_size,
                                orig->array.self.bc + i1 * elt_size,
                                l * elt_size);
                }
        } else if (t != ecl_array_elttype(orig) || t == aet_bit) {
                while (l--) {
                        ecl_aset_unsafe(dest, i0++,
                                        ecl_aref_unsafe(orig, i1++));
                }
        } else {
		cl_index elt_size = ecl_aet_size[t];
		memcpy(dest->array.self.bc + i0 * elt_size,
                       orig->array.self.bc + i1 * elt_size,
                       l * elt_size);
	}
}

void
ecl_reverse_subarray(cl_object x, cl_index i0, cl_index i1)
{
	cl_elttype t = ecl_array_elttype(x);
	cl_index i, j;
	if (x->array.dim == 0) {
		return;
	}
	if (i1 >= x->array.dim) {
		i1 = x->array.dim;
	}
	switch (t) {
	case aet_object:
	case aet_fix:
	case aet_index:
		for (i = i0, j = i1-1;  i < j;  i++, --j) {
			cl_object y = x->vector.self.t[i];
			x->vector.self.t[i] = x->vector.self.t[j];
			x->vector.self.t[j] = y;
		}
		break;
	case aet_sf:
		for (i = i0, j = i1-1;  i < j;  i++, --j) {
			float y = x->array.self.sf[i];
			x->array.self.sf[i] = x->array.self.sf[j];
			x->array.self.sf[j] = y;
		}
		break;
	case aet_df:
		for (i = i0, j = i1-1;  i < j;  i++, --j) {
			double y = x->array.self.df[i];
			x->array.self.df[i] = x->array.self.df[j];
			x->array.self.df[j] = y;
		}
		break;
	case aet_bc:
		for (i = i0, j = i1-1;  i < j;  i++, --j) {
			ecl_base_char y = x->array.self.bc[i];
			x->array.self.bc[i] = x->array.self.bc[j];
                        x->array.self.bc[j] = y;
		}
		break;
	case aet_b8:
        case aet_i8:
		for (i = i0, j = i1-1;  i < j;  i++, --j) {
			ecl_uint8_t y = x->array.self.b8[i];
			x->array.self.b8[i] = x->array.self.b8[j];
			x->array.self.b8[j] = y;
		}
		break;
#ifdef ecl_uint16_t
	case aet_b16:
        case aet_i16:
		for (i = i0, j = i1-1;  i < j;  i++, --j) {
			ecl_uint16_t y = x->array.self.b16[i];
			x->array.self.b16[i] = x->array.self.b16[j];
			x->array.self.b16[j] = y;
		}
		break;
#endif
#ifdef ecl_uint32_t
	case aet_b32:
        case aet_i32:
		for (i = i0, j = i1-1;  i < j;  i++, --j) {
			ecl_uint32_t y = x->array.self.b32[i];
			x->array.self.b32[i] = x->array.self.b32[j];
			x->array.self.b32[j] = y;
		}
		break;
#endif
#ifdef ecl_uint64_t
	case aet_b64:
        case aet_i64:
		for (i = i0, j = i1-1;  i < j;  i++, --j) {
			ecl_uint64_t y = x->array.self.b64[i];
			x->array.self.b64[i] = x->array.self.b64[j];
			x->array.self.b64[j] = y;
		}
		break;
#endif
#ifdef ECL_UNICODE
	case aet_ch:
		for (i = i0, j = i1-1;  i < j;  i++, --j) {
			ecl_character y = x->array.self.c[i];
			x->array.self.c[i] = x->array.self.c[j];
                        x->array.self.c[j] = y;
		}
		break;
#endif
	case aet_bit:
		for (i = i0 + x->vector.offset,
		     j = i1 + x->vector.offset - 1;
		     i < j;
		     i++, --j) {
			int k = x->array.self.bit[i/CHAR_BIT]&(0200>>i%CHAR_BIT);
			if (x->array.self.bit[j/CHAR_BIT]&(0200>>j%CHAR_BIT))
				x->array.self.bit[i/CHAR_BIT]
				|= 0200>>i%CHAR_BIT;
			else
				x->array.self.bit[i/CHAR_BIT]
				&= ~(0200>>i%CHAR_BIT);
			if (k)
				x->array.self.bit[j/CHAR_BIT]
				|= 0200>>j%CHAR_BIT;
			else
				x->array.self.bit[j/CHAR_BIT]
				&= ~(0200>>j%CHAR_BIT);
		}
		break;
	default:
		FEbad_aet();
	}
}

cl_object
si_copy_subarray(cl_object dest, cl_object start0,
                 cl_object orig, cl_object start1, cl_object length)
{
        ecl_copy_subarray(dest, fixnnint(start0),
                          orig, fixnnint(start1),
                          fixnnint(length));
        @(return dest)
}

cl_object
si_fill_array_with_elt(cl_object x, cl_object elt, cl_object start, cl_object end)
{
	cl_elttype t = ecl_array_elttype(x);
        cl_index first = fixnnint(start);
        cl_index last = Null(end)? x->array.dim : fixnnint(end);
        if (first >= last) {
                goto END;
        }
	switch (t) {
	case aet_object: {
                cl_object *p = x->vector.self.t + first;
		for (first = last - first; first; --first, ++p) { *p = elt; }
		break;
        }
	case aet_bc: {
                ecl_base_char e = ecl_char_code(elt);
                ecl_base_char *p = x->vector.self.bc + first;
		for (first = last - first; first; --first, ++p) { *p = e; }
		break;
        }
#ifdef ECL_UNICODE
	case aet_ch: {
                ecl_character e = ecl_char_code(elt);
                ecl_character *p = x->vector.self.c + first;
		for (first = last - first; first; --first, ++p) { *p = e; }
		break;
        }
#endif
	case aet_fix: {
                cl_fixnum e = fixint(elt);
                cl_fixnum *p = x->vector.self.fix + first;
		for (first = last - first; first; --first, ++p) { *p = e; }
		break;
        }
	case aet_index: {
                cl_index e = fixnnint(elt);
                cl_index *p = x->vector.self.index + first;
		for (first = last - first; first; --first, ++p) { *p = e; }
		break;
        }
	case aet_sf: {
                float e = ecl_to_float(elt);
                float *p = x->vector.self.sf + first;
		for (first = last - first; first; --first, ++p) { *p = e; }
		break;
        }
	case aet_df: {
                double e = ecl_to_double(elt);
                double *p = x->vector.self.df + first;
		for (first = last - first; first; --first, ++p) { *p = e; }
		break;
        }
	case aet_b8: {
                uint8_t e = ecl_to_uint8_t(elt);
                uint8_t *p = x->vector.self.b8 + first;
		for (first = last - first; first; --first, ++p) { *p = e; }
		break;
        }
	case aet_i8: {
                int8_t e = ecl_to_int8_t(elt);
                int8_t *p = x->vector.self.i8 + first;
		for (first = last - first; first; --first, ++p) { *p = e; }
		break;
        }
#ifdef ecl_uint16_t
	case aet_b16: {
                ecl_uint16_t e = ecl_to_uint16_t(elt);
                ecl_uint16_t *p = x->vector.self.b16 + first;
		for (first = last - first; first; --first, ++p) { *p = e; }
		break;
        }
	case aet_i16: {
                ecl_int16_t e = ecl_to_int16_t(elt);
                ecl_int16_t *p = x->vector.self.i16 + first;
		for (first = last - first; first; --first, ++p) { *p = e; }
		break;
        }
#endif
#ifdef ecl_uint32_t
	case aet_b32: {
                ecl_uint32_t e = ecl_to_uint32_t(elt);
                ecl_uint32_t *p = x->vector.self.b32 + first;
		for (first = last - first; first; --first, ++p) { *p = e; }
		break;
        }
	case aet_i32: {
                ecl_int32_t e = ecl_to_int32_t(elt);
                ecl_int32_t *p = x->vector.self.i32 + first;
		for (first = last - first; first; --first, ++p) { *p = e; }
		break;
        }
#endif
#ifdef ecl_uint64_t
	case aet_b64: {
                ecl_uint64_t e = ecl_to_uint64_t(elt);
                ecl_uint64_t *p = x->vector.self.b64 + first;
		for (first = last - first; first; --first, ++p) { *p = e; }
		break;
        }
	case aet_i64: {
                ecl_int64_t e = ecl_to_int64_t(elt);
                ecl_int64_t *p = x->vector.self.i64 + first;
		for (first = last - first; first; --first, ++p) { *p = e; }
		break;
        }
#endif
	case aet_bit: {
                int i = ecl_to_bit(elt);
		for (last -= first, first += x->vector.offset; last; --last, ++first) {
                        int mask = 0200>>first%CHAR_BIT;
                        if (i == 0)
                                x->vector.self.bit[first/CHAR_BIT] &= ~mask;
                        else
                                x->vector.self.bit[first/CHAR_BIT] |= mask;
		}
		break;
        }
	default:
		FEbad_aet();
	}
 END:
        @(return x)
}
